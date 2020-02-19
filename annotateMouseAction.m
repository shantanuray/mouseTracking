function [roiData, reachingEvents, isTremorCase, refPixelLength] = annotateMouseAction(videoFile, markingFile, varargin)
% [roiData, reachingEvents, isTremorCase, refPixelLength] = ...
%       annotateMouseAction(videoFile, markingFile,...
%               'BodyParts', {'hand', 'wrist', 'nose', 'littlefinger', 'index'},...
%               'VideoAngle', 'left',...
%               'Mode', 'Manual');
% [roiData, reachingEvents, isTremorCase, refPixelLength] = ...
%       annotateMouseAction(videoFile, markingFile,...
%               'BodyParts', {'hand', 'wrist', 'nose', 'littlefinger', 'index'},...
%               'MarkingROILocation', [120, 160; 400, 400],...
%               'Mode', 'Manual');
% Inputs:
%   videoFile:          '18LLR.mov'
%   markingFile:        Output of the DeepLabCut AnalyzeVideos (h5 or mat file with the markings)
%                       eg. '18LLR_DeepCut_resnet50_reaching-left14Junshuffle5_450000.h5'
%   'BodyParts':        {'hand', 'wrist', 'nose', 'littlefinger', 'index'} % Default
%   'VideoAngle':       'left' or 'right' - Use for default MarkingROILocation
%   'MarkingROILocation': If a custom ROI was marked in DeepLabCut
%                       Defaults -  Left Video Angle - [320, 160; 600, 600];
%                                  Right Video Angle - [120, 160; 400, 400];
%   'Mode':             'Manual' or 'Auto'
%
% Outputs:
%   - roiData:          Position of the selection by user for paw, pellet, nose, etc.  
%                       Structure with fields ('roi','marking','frameCount')
%                       where roi is a cell of body parts marked {'hand', 'wrist', ...},
%                       marking is (x,y) coordinates of each body part marking
%                           - nrow = number of frames
%                           - ncol = (pellet, number of body parts) * 3 (x, y, likelihood)
%                           - pellet_x, pellet_y, pellet_p, hand_x, hand_y, hand_p, ...
%                       frameCount is the index of the frame
%   - reachingEvents:   The annotation of different events in the reaching task. 
%                       Each event has three parts - 
%                       * action - Reach/ Grasp/ Retrieve
%                       * Further classification of the success of the action
%                       * Consequence of the action
%                           Structure with fields:
%                           ('action', 'actionType', 'consequence', 'marking', 'frameCount')
%   - isTremorCase:     Was a tremor identified by the observer in the mouse grab
%                       logical (0,1)
%   - refPixelLength:   Known reference length for comparing number of pixels to length
% 
% Guides user to annotate the mouse action as it tries to grab the pellet as 
% Action (Reach/ Grasp/ Retrieve), whether it was successful or not and the 
% consequence of the action
% 
% The program requires the paw, nose position (provided by the DeepLabCut)
% Mouse Tracking code. 
% Steps of the program:
%   1. Identify pellet: At the start of the program, user is asked
%       to identify the pellet. User should only identify the target
%       pellet that the mouse was trying to grab in the task. There can 
%       be only one target pellet for a given video currently
%       TODO: Handle multiple targets
%   2. Verify regions of interest: User can verify regions of interest 
%       i.e. whether the digits, paw, nose were marked properly via DeepLabCut
%       and if not, correct it
%   3. Identify and classify action: At each stage the user is also asked if
%       the mouse grabbed the pellet and if so, classify it as:
%                       * Action - Reach/ Grasp/ Retrieve
%                       * Success/Error of the action
%                       * Consequence of the action
%   4. Identify if there was tremor: At the end of the analysis before quitting
%       user is asked if the user saw tremor
%
% Usage:
% Default left reaching task with standard ROI marked in DeepLabCut:
% [...] = annotateMouseAction('18LLR.mov', ...
%                       '18LLR_DeepCut_resnet50_reaching-left14Junshuffle5_450000.h5')
% Default left reaching task with custom ROI marked in DeepLabCut:
% [...] = annotateMouseAction('18LLR.mov', ...
%                       '18LLR_DeepCut_resnet50_reaching-left14Junshuffle5_450000.h5',...
%                       'MarkingROILocation', [320, 160; 600, 400]);
% Default right reaching task:
% [...] = annotateMouseAction('18LLR.mov', ...
%                       '18LLR_DeepCut_resnet50_reaching-left14Junshuffle5_450000.h5',...
%                       'VideoAngle', 'left');
% Custom: 
% [...] = annotateMouseAction('18LLR.mov', ...
%                       '18LLR_DeepCut_resnet50_reaching-left14Junshuffle5_450000.h5',...
%                       'BodyParts', {'hand', 'wrist', 'nose', 'littlefinger', 'index'},...
%                       'MarkingROILocation', [120, 160; 400, 400]);
p = readInput(varargin);
[obj, roiData, reachingEvents, isTremorCase, videoFile] = initializeSystem(videoFile, markingFile, p);

%% Start processing
% Read all frames at one time (TODO Optimize this)
frameCount = 0;
totalFrameCount = 0;
while hasFrame(obj.video)
    totalFrameCount = totalFrameCount + 1;
    frame(:, :, :, totalFrameCount) = readFrame(obj.video);
end
% Update frame count
frameCount = frameCount + 1;
curFrame = frame(:, :, :, frameCount);
% Initialize the previous and next frames
oldFrame = zeros(size(curFrame));
nextFrame = frame(:, :, :, frameCount+1);

% To display the marked body part, use a box of predetermined size and color range
boxSize  = 5;   % 5 x 5
boxColors = distinguishable_colors(length(roiData.roi));
minLikelihood = roiData.minimumLikelihood;

% Mark the pellet
% Please note pellet is marked only once
% Assumption: Pellet does not move. If pellet moves, we will have to update the marking
pelletMarked = find(strcmpi(roiData.roi, 'Pellet'));
if strcmpi(p.Results.Mode, 'Manual')
    h1=figure;
    % Put figure on the top left corner
    % Adjust size for optimal viewing. Remove toolbars
    % Note the original size is 1080 x 1920
    set(h1,'Position',[606   393   835   464], 'Toolbar','None', 'Menubar','None');     

    h0=figure;
    set(h0,'Position',[1   587   480   270], 'Toolbar','None', 'Menubar','None');   

    h2=figure;
    set(h2,'Position',[1   294   480   270], 'Toolbar','None', 'Menubar','None');
    if length(pelletMarked) == 0
        disp('Mark the pellet in the displayed image');
        h1 = imdisplay(curFrame, h1, frameCount);
        pelletMarking = [imageMark(curFrame, h1), 1]; % Pellet position marked with 100% probability
        % Add pellet to ROI
        roiData.roi = ['pellet', roiData.roi];
        boxColors = distinguishable_colors(length(roiData.roi));
        roiData.marking = [repmat(pelletMarking', 1, size(roiData.marking, 2)); roiData.marking];
        % Mark the reference for marking velocity
        disp('Mark a rectangle with a known height (reference for measuring velocity')
        refPosition = getrect();
        refLength = input('What is the real world height of this reference? (in cms)    ');
        refPixelLength=refLength/refPosition(1,4);
    end
% elseif isempty(pelletMarked)
%     pelletMarking = [10, 10, 0.05];
%     refPixelLength = 1;
%     roiData.roi = ['pellet', roiData.roi];
%     boxColors = distinguishable_colors(length(roiData.roi));
%     roiData.marking = [repmat(pelletMarking', 1, size(roiData.marking, 2)); roiData.marking];
else
    refPixelLength = 1;
    boxColors = distinguishable_colors(length(roiData.roi));
end


if length(pelletMarked) > 0
    pelletMarking = roiData.marking((pelletMarked(1)-1)*3+1:(pelletMarked(1)-1)*3+3, frameCount);
    % Render the marking as a box of size boxSize x boxSize in frame with color chosen from bodyBoxColors
    % TODO Take care of points on the edge where boxSize will be outside the edge of image
    if pelletMarking(3) >= minLikelihood
        % boxPaint is a box of size (boxSize x boxSize) with (rgb) from boxColors 
        %   (eg. 5x5x3 if boxSize = 5)
        boxPaint = permute(repmat(repmat(uint8(255*boxColors(pelletMarked(1), :)), boxSize, 1), 1, 1, boxSize), [3, 1, 2]);
        curFrame(int16(pelletMarking(2)-(boxSize-1)/2:pelletMarking(2)+(boxSize-1)/2), ...
            int16(pelletMarking(1)-(boxSize-1)/2:pelletMarking(1)+(boxSize-1)/2), :) =...
        boxPaint;
    end
    if strcmpi(p.Results.Mode, 'Manual')
        h1 = imdisplay(curFrame, h1, frameCount);
    end
end

% Keep saving
[matDir,matPrefix]=fileparts(videoFile);
save(fullfile(matDir,[matPrefix,'.mat']), 'roiData', 'reachingEvents', 'isTremorCase', 'videoFile','refPixelLength');

reply = 'y';
while ~strcmpi(reply,'x') & strcmpi(p.Results.Mode, 'Manual')
    curFrame = frame(:, :, :, frameCount);
    frameUnmarked = curFrame;
    marking = roiData.marking(:, frameCount); % (x,y, likelihood) for all markings as a single row
    curFrame = renderMarking(frameUnmarked, marking, roiData.roi, frameCount);
    % Update display
    h1 = imdisplay(curFrame, h1, frameCount);
    if (frameCount < totalFrameCount)
        % Read frame
        nextFrameUnmarked = frame(:, :, :, frameCount + 1);
        marking_next = roiData.marking(:, frameCount + 1);
        nextFrame = renderMarking(nextFrameUnmarked, marking_next, roiData.roi, frameCount + 1);
        % Update display
        h2 = imdisplay(nextFrame, h2, frameCount + 1);
    else
        nextFrame = [];
    end
    reply = 'y';
    while ~isempty(reply)
        outcome = '';
        menuindex = 0;
        figure(h1);
        reply = input(['\nDo you wish to annotate a reach or change the marking?\n',...
            'Enter  => Next Image [Press Enter]\n',...
            '[v/V]  => Go to frame \n',...
            '1      => Change Marking\n',...
            '2      => Annotate a Reach\n',...
            '[x/X]  => Exit]    \n'],'s');
        if isempty(reply)|strcmpi(reply, 'x')
            save(fullfile(matDir,[matPrefix,'.mat']), 'roiData', 'reachingEvents', 'isTremorCase', 'videoFile','refPixelLength');
            oldFrame = curFrame;
            h0=imdisplay(oldFrame, h0, frameCount);

            if ~isempty(nextFrame)
                curFrame = nextFrameUnmarked;
                frameCount = frameCount+1;
            else
                break;
            end
            break;
        end
        
        switch lower(reply)
        case {'v'}
            actionNum = input(['\nWhich frame number would you like to jump to [1:', num2str(totalFrameCount),']?\n',...
                'Enter  => Return to main menu [Press Enter]  \n'],'s');
            actionNum = str2num(actionNum);
            if ~isempty(actionNum) & actionNum>0 & actionNum<=totalFrameCount
                frameCount = actionNum; % Assuming integer; TODO What if double?
            end
            break;
        case {'1'}
            % Call imageMark for the given frame to mark the object
            actionNum = '0';
            menustr = sprintf('\n%s\n', 'Which body part marking would you like to change?');
            for p = 1:length(roiData.roi)
                menustr = strcat(menustr, sprintf('\n%d => %s\n\r', p, roiData.roi{p}));
            end;
            menustr = strcat(menustr, sprintf('\n%s\n', 'Enter  => Return to main menu [Press Enter]'));
            while ~isempty(actionNum)
                % TODO Initialize menu dynamically based on marked body parts
                actionNum = input(menustr,'s');
                actionNum = str2num(actionNum);
                if ~isempty(actionNum) & actionNum > 0 & actionNum <= length(roiData.roi)
                    disp(['Mark the ', roiData.roi{actionNum}, ' in the displayed image']);
                    newMarking = [imageMark(curFrame, h1), 1]; % Mark new marking with 100% likelihood
                    % Update the saved marking data
                    roiData.marking((actionNum-1)*3+1:(actionNum-1)*3+3, frameCount) = newMarking;
                    % Reset the frame to the unmarked version of the frame and
                    % Re-render all the markings
                    marking = roiData.marking(:, frameCount);
                    curFrame = renderMarking(frameUnmarked, marking, roiData.roi, frameCount);
                    % Update display
                    h1 = imdisplay(curFrame, h1, frameCount);
                    actionNum = '0';
                end
            end
        case {'2'}
            actionNum = '0';
            action = '';
            outcome = '';
            while ~isempty(actionNum)
                actionNum = input(['\nDo you wish to continue to next image [Enter]\n',...
                    'Or\Annotate Event [Press 0, 1, ... or 7] \n',...
                    '0 => Initialize\n',...
                    '1 => Cross Doorway\n',...
                    '2 => Reach\n',...
                    '3 => Grasp\n',...
                    '4 => Retrieve\n',...
                    '5 => Laser Light On\n',...
                    '6 => Laser Light Off\n',...
                    '7 => LED Counter\n'],'s');
                switch actionNum
                case '0'
                    action = 'Initialize';
                    % For special cases of Initialize, we do not have custom menus for
                    %   - Action type
                    %   - Consequence
                    % Hence, actionType = [], consequence = []
                    reachingEvents = [reachingEvents; ...
                        struct('action', action, 'actionType', [], 'consequence', [],...
                            'roi', {roiData.roi},...
                            'marking', roiData.marking(:, frameCount),...
                            'counterNumber', [],...
                            'frameCount', frameCount)];
                    reply = '';
                case '1'
                    action = 'Cross Doorway';
                    % For special cases of Initialize, we do not have custom menus for
                    %   - Action type
                    %   - Consequence
                    % Hence, actionType = [], consequence = []
                    reachingEvents = [reachingEvents; ...
                        struct('action', action, 'actionType', [], 'consequence', [],...
                            'roi', {roiData.roi},...
                            'marking', roiData.marking(:, frameCount),...
                            'counterNumber', [],...
                            'frameCount', frameCount)];
                    reply = '';
                case '2'
                    action = 'Reach';
                case '3'
                    action = 'Grasp';
                case '4'
                    action = 'Retrieve';
                case '5'
                    action = 'Laser Light On';
                    % For special cases of Light On, we do not have custom menus for
                    %   - Action type
                    %   - Consequence
                    % Hence, actionType = [], consequence = []
                    reachingEvents = [reachingEvents; ...
                        struct('action', action, 'actionType', [], 'consequence', [],...
                            'roi', {roiData.roi},...
                            'marking', roiData.marking(:, frameCount),...
                            'counterNumber', [],...
                            'frameCount', frameCount)];
                    reply = '';
                case '6'
                    action = 'Laser Light Off';
                    % For special cases of Light Off, we do not have custom menus for
                    %   - Action type
                    %   - Consequence
                    % Hence, actionType = [], consequence = []
                    reachingEvents = [reachingEvents; ...
                        struct('action', action, 'actionType', [], 'consequence', [],...
                            'roi', {roiData.roi},...
                            'marking', roiData.marking(:, frameCount),...
                            'counterNumber', [],...
                            'frameCount', frameCount)];
                    reply = '';
                case '7'
                    action = 'LED Counter';
                    % For special cases of LED Counter, we do not have custom menus for
                    %   - Action type
                    %   - Consequence
                    % Hence, actionType = [], consequence = []
                    counterNumber = input('What is the LED counter number?    ');
                    reachingEvents = [reachingEvents; ...
                        struct('action', action, 'actionType', [], 'consequence', [],...
                            'roi', {roiData.roi},...
                            'marking', roiData.marking(:, frameCount),...
                            'counterNumber', counterNumber,...
                            'frameCount', frameCount)];
                    reply = '';
                case ''
                    action = '';
                    reply = '';
                otherwise
                    actionNum = '0';
                    disp('Warning: You have marked an incorrect input. Please try again.')
                end
                % For special cases of Reach, Grasp and Retrieve, we have custom menus for
                %   - Action type (Reach, Grasp, Retrieve type)
                %   - Consequence
                [truefalse, menuindex] = ismember(action, {obj.actionFigure.action});
                if menuindex>0
                    actionOptions = obj.actionFigure(menuindex).type;
                    consequenceOptions = obj.actionFigure(menuindex).consequence;
                    disp(['Specify Action Success']);
                    actionType = menuSelect(actionOptions, false, true);
                    disp(['Specify Action Consequence']);
                    consequence = menuSelect(consequenceOptions, false, true);
                    reachingEvents = [reachingEvents; ...
                        struct('action', action, 'actionType', actionType,...
                            'consequence', consequence,...
                            'roi', {roiData.roi},...
                            'marking', roiData.marking(:, frameCount),...
                            'counterNumber', [],...
                            'frameCount', frameCount)];
                    reply = '';
                end
            end
        otherwise
            reply = 'y';
            disp('Warning: You have marked an incorrect input. Please try again.')
        end
        save(fullfile(matDir,[matPrefix,'.mat']), 'roiData', 'reachingEvents', 'isTremorCase', 'videoFile','refPixelLength');
    end
end

[matDir,matPrefix]=fileparts(videoFile);
analyzeThis = 'no';
if strcmpi(p.Results.Mode, 'Manual')
    newMatDir = input(['Saving MAT file in ', matDir, ', Okay? [Enter - Yes | Any key - No]  '], 's');
    if ~isempty(newMatDir)
        newMatDir = uigetdir(matDir, 'Pick a Directory');
    end
    if ~(isempty(newMatDir) | newMatDir == 0)
        matDir = newMatDir;
    end
    analyzeThis = input('Do you wish to see if the mouse actions were marked correctly? [Yes - Enter]    ','s');
end
save(fullfile(matDir, [matPrefix,'.mat']), 'roiData', 'reachingEvents', 'isTremorCase', 'videoFile','refPixelLength');
if isempty(analyzeThis)
    analyzeMouseAnnotation(roiData, reachingEvents, videoFile,... 
        'RefTargetName', roiData.refTargetName, 'RefBodyPartName', roiData.bodyPartName,... 
        'ModeFlag', 'foreground', 'WriteFrameCount', true);
end

return;

    %% Read input
    function p = readInput(input)
        p = inputParser;
        defaultBodyParts = {'hand', 'wrist', 'nose', 'littlefinger', 'index'};
        defaultRefTargetName = 'pellet';
        defaultBodyPartName = 'hand';
        defaultMarkingH5Location = '/df_with_missing';
        defaultMarkingH5DataSet = '/table';
        defaultVideoAngle = '';
        defaultMarkingROILocation = [320, 160; 600, 400]; % [x1, y1; x2, y2] Left Reaching
        % defaultMarkingROILocation = [120, 160; 400, 400]; % Right Reaching Task
        defaultMinimumLikelihood = 0.05; % [x1, y1; x2, y2] Left Reaching
        defaultMode = 'Manual'; % or 'Auto'
        
        addParameter(p,'BodyParts',defaultBodyParts, @iscell);
        addParameter(p,'RefTargetName',defaultRefTargetName, @ischar);
        addParameter(p,'BodyPartName',defaultBodyPartName, @ischar);
        addParameter(p,'MarkingH5Location',defaultMarkingH5Location, @ischar);
        addParameter(p,'MarkingH5DataSet',defaultMarkingH5DataSet, @ischar);
        addParameter(p,'VideoAngle',defaultVideoAngle, @ischar);
        addParameter(p,'MarkingROILocation',defaultMarkingROILocation, @isnumeric);
        addParameter(p,'MinimumLikelihood',defaultMinimumLikelihood, @isnumeric);
        addParameter(p,'Mode',defaultMode, @ischar);

        parse(p, input{:});
    end

    %% Initialize and setup system objects and outputs
    function [obj, roiData, reachingEvents, isTremorCase, videoFile] = initializeSystem(videoFile, markingFile, p)

        if isempty(p.Results.MarkingROILocation)
            switch lower(p.Results.VideoAngle)
                case 'left'
                    markingROILocation = [320, 160; 600, 600];
                case 'right'
                    markingROILocation = [120, 160; 400, 400];
            end
        else
            markingROILocation = p.Results.MarkingROILocation;
        end;

        % Get folder where the mouse reaching task images are stored
        if isempty(videoFile)
            disp('Select video for annotating mouse grabs (*.mp4, *.avi, *.mov)');
            [fileName, fpath] = uigetfile({'*.mp4;*.avi;*.mov', 'Select video for annotating mouse grabs (*.mp4, *.avi, *.mov)'});
            videoFile = fullfile(fpath, fileName);
            [~, obj.savePrefix] = fileparts(fileName);
        else
            [fpath, obj.savePrefix] = fileparts(videoFile);
        end

        if ~isempty(videoFile)
            % Read video file
            obj.video = VideoReader(videoFile);
        else
            error('Could not find video. Please check and try again');
        end
        
        %% Read the output of the DeepLabCut analysis
        % Obtain the body parts that were marked
%         roiData = struct([]);
        roiData.roi = p.Results.BodyParts;
        roiData.refTargetName = p.Results.RefTargetName;
        roiData.bodyPartName = p.Results.BodyPartName;
        roiData.minimumLikelihood = p.Results.MinimumLikelihood;
        % Read the body part markings from h5 file or mat file
        if isempty(markingFile)
            error('Could not find h5/ mat file with markings. Run DeepLabCut AnalyzeVideos.py to get the h5 file or run markMouseAction to manually mark the mouse body parts.');
        else
            [fpath, fname, fext] = fileparts(markingFile);
            if strcmpi(fext, '.h5')
                % Structure of the h5 file:
                %   - Location          : /df_with_missing
                %   - Dataset           : /table
                %   - Data structure    : [x, y, likelihood] for each body part
                h5_obj = h5read(markingFile,... 
                    [p.Results.MarkingH5Location, p.Results.MarkingH5DataSet]);
                roiData.marking = h5_obj.values_block_0;
                roiData.frameCount = double(h5_obj.index + 1);
                % Structure of marking is [x, y, likelihood] for each body part
                % Adding MarkingROILocation (xmin, ymin) to (x, y) of each body part
                %  - p. Results.MarkingROILocation(1,1:2)
                roiData.marking(reshape([3 3; 1 2]'*[0:length(roiData.roi)-1; ones(1, length(roiData.roi))], 1, length(roiData.roi)*2), :) = ...
                        roiData.marking(reshape([3 3; 1 2]'*[0:length(roiData.roi)-1; ones(1, length(roiData.roi))], 1, length(roiData.roi)*2), :) + ...
                                repmat(...
                                repmat(...
                                    markingROILocation(1, 1:2), size(roiData.marking, 2), 1)',... 
                                    length(roiData.roi), 1);
                % Initialize outputs
                reachingEvents = struct([]);
                isTremorCase = logical(0);
            elseif strcmpi(fext, '.mat')
                load(markingFile);
            end
        end

        % Initialize mouse action categories
        obj.actionFigure = [
            struct('action','Reach','type',{{'Successful Reach','Error: Overreach','Error: Under reach'}},...
                'consequence',{{'Grasp','Miss','Pellet dispersed'}}),...
            struct('action','Grasp','type',{{'Successful Grasp','Error: Failure to grasp', 'Error: Abnormal grip'}},...
                'consequence',{{'Retrieve','Pellet dispersed'}}),...
            struct('action','Retrieve','type',{{'Retrieval','Error: Drop'}},...
                'consequence',{{'Pellet in mouth','Failure to supinate','Failure to transfer', 'Slip'}})
        ];
    end

    % For the given frame/image, ask the user to mark objects by drawing a rectangle around
    %   the object. Size of the marking can be anything as long as the center of marking 
    %   matches the center of the object
    % imageMark(img, h) Returns position (x, y) of the center of the marked image
    function marking = imageMark(img, h)
        if nargin>=2
            % Bring image to forefront
            figure(h);
        end
        % Ask user to draw rectangle to mark object
        position = getrect();
        % Get the center of the rectangle
        marking = ceil([position(1:2) + position(3:4)/2]);
    end

    %% Render all the markings
    function frame = renderMarking(frameUnmarked, marking, roi, frameCount)
        frame = frameUnmarked;
        
        % Please note minLikelihood, boxColors, boxSize are being accessed from calling function
        % Render the marking as a box of size boxSize x boxSize in frame with color chosen from bodyBoxColors
        % TODO Take care of points on the edge where boxSize will be outside the edge of image
        for bp = 1:length(roi) % Number of body parts = marking/3 for (x, y, likelihood)
            if marking((bp-1)*3+3) >= minLikelihood
                % boxPaint is a matrix of size (boxSize x boxSize) with value = (rgb) from boxColors 
                %   (eg. 5x5x3 if boxSize = 5)
                boxPaint = permute(repmat(repmat(uint8(255*boxColors(bp, :)), boxSize, 1), 1, 1, boxSize), [3, 1, 2]);
                frame(int16(marking((bp-1)*3+2)-(boxSize-1)/2:marking((bp-1)*3+2)+(boxSize-1)/2), ...
                    int16(marking((bp-1)*3+1)-(boxSize-1)/2:marking((bp-1)*3+1)+(boxSize-1)/2), :) =...
                boxPaint;
            end
        end
    end

    function fileName = saveImage(img, fpath, fprefix)
        if ~isempty(img)
            fileName = fullfile(fpath, [fprefix,'.png']);
            %% Write image
            imwrite(img, fileName, 'PNG');
        else
            fileName = '';
        end
    end

    %% For the given box, [x y width height], return the selected image with actual
    % coordinates [row(1):row(end), column(1):column(end)]
    function imgMarked = getImageMarked(img, position)
        imgMarked = img(position(2):position(2)+position(4)-1, position(1):position(1)+position(3)-1,:);
    end

    function h = imdisplay(img,h, frameCount)
        if nargin<3 frameCount=1;end
        frameCountWriteFlag = true;
        frameCountWriteFontSize = 32;
        frameCountWriteFont = 'Arial';
        frameCountWriteCharWidth = ceil(5*32/18);
        frameCountWriteBoxHorzPadding = ceil(7*32/18);
        frameCountWriteBoxVertPadding = 1;
        frameCountWriteCharHeight = frameCountWriteFontSize+2;
        frameCountWritePadding = 5;
        frameCountWriteTextColor = 'black';
        frameCountWriteBoxColor = 'white';
        if ~ishandle(h)
            % If the figure was closed, reopen it
            h = figure;
            % Put figure on the top left corner
            % Adjust size for optimal viewing. Remove toolbars
            % Note the original size is 1080 x 1920
            set(h,'Position',[0 350 800 450], 'Toolbar','None', 'Menubar','None');  
        else
            figure(h);
        end
        if frameCountWriteFlag
            img = insertText(img,...
                [ceil(size(img,2)-(frameCountWriteFontSize*0.7*floor(log10(frameCount)+1))-frameCountWritePadding) (frameCountWriteFontSize+frameCountWriteBoxVertPadding+frameCountWritePadding)],...
                frameCount,...
                'Font', frameCountWriteFont, 'FontSize', frameCountWriteFontSize, 'AnchorPoint', 'Center',...
                'TextColor', frameCountWriteTextColor, 'BoxColor',frameCountWriteBoxColor);
        end
        % Show the image and fit it to the figure window
        imshow(img,'InitialMagnification','fit','Border','tight');
    end

    function out = menuSelect(options, skip, newoption)
        % out = menuSelect(options, skip, newoption)
        % options     - (cell array) the menu options; out = one of the options
        % skip        - (boolean) if skip option has to be added - User clicks on Enter; out = ''
        % newoption   - (boolean) specify a new value - User clicks N/n; out = new value type by user
        out = '';
        menureply = '';
        menustr = '';
        if skip
            menustr = [menustr, 'Skip? Press Enter \nOr\n'];
        end
        menustr = [menustr, 'Choose one of the following \n'];
        for i = 1:length(options)
            menustr = [menustr, num2str(i), ' => ', options{i}, '\n'];
        end
        if newoption
            menustr = [menustr, 'New type? Press [N/n]\n'];
        end
        while isempty(menureply)
            menureply = input(menustr,'s');
            if skip & isempty(menureply)
                % Skip. Return empty
                return;
            elseif ~isempty(menureply)
                if strcmpi(menureply,'n') % New option
                    out = input('Type in new category and click enter >>  ','s');
                else % Existing option chosen
                    menunum = str2num(menureply);
                    if menunum>0 & menunum<=length(options)
                        out = options{menunum};
                    else
                        menureply = '';
                        disp('Warning: Incorrect entry. Try again.')
                    end
                end
            end
        end
    end
end