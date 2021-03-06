function [roiData, grabResult, isTremorCase, refPixelLength, videoFile] = markMouseAction(varargin)
% [roiData, grabResult, isTremorCase, videoFile] = markMouseAction;
% 
% Guides user to mark the mouse paw as it tries to grab the pellet
% The program does not detect paw or pellet automatically but
% instead guides the user to identify the required inputs.
% Steps of the program:
%   1. Identify pellet: At the start of the program, user is asked
%       to identify the pellet. User should only identify the target
%       pellet that the mouse was trying to grab in the task. There can 
%       be only one target pellet for a given video currently
%       TODO: Handle multiple targets
%   2a. Identify regions of interest: User can mark  regions of interest 
%       at any time and provide what is being marked (eg. nose)
%   2b. Identify paw: In every frame, user is asked to identify
%       the position of the paw
%   3. Identify and classify action: At each stage the user is also asked if
%       the mouse grabbed the pellet and if so, classify it as:
%                       * Action - Reach/ Grasp/ Retrieve
%                       * Success/Error of the action
%                       * Consequence of the action
%                       Structure with fields ('outcome','position','centroid','imageFile','frameCount')
%   4. Identify if there was tremor: At the end of the analysis before quitting
%       user is asked if the user saw tremor
% 
% Outputs:
%   - roiData:          Position of the selection by user for paw, pellet, node, etc.  
%                       Structure with fields ('roi','position','centroid',imageFile','frameCount')
%                       where roi is one of (paw, pellet, nose, ...)
%   - grabResult:       The description of the action. It has three parts
%                       * action - Reach/ Grasp/ Retrieve
%                       * Further classification of the success of the action
%                       * Consequence of the action
%                       Structure with fields ('action','actionType','consequence','position','centroid','imageFile','frameCount')
%   - isTremorCase:     Was a tremor identified by the observer in the mouse grab
%                       logical (0,1)
% Usage:
% [...] = markMouseAction; 
%   User will be asked to point the video file
% [...] = markMouseAction('VideoFile', videoFile);
%   Provide video file. obj.standardImageSize assumed to be [64 x 64 pixels]
% [...] = markMouseAction('VideoFile', 'test.mp4', 'Mode', 'default', StandardImageSize', [64 64]);
%   Provide video file and provide obj.standardImageSize and
%   mode: 
%   - Default   - Pellet and paw
%   - Nose      - Nose only
%   - All       - Paw, Pellet and nose

%% TODO Provide support for image files
% [...] = markMouseAction('RawImageFolder', fpath, 'StandardImageSize', standardImageSize);
%   Provide path where the image files are stored

p = readInput(varargin);
[obj, roiData, grabResult, isTremorCase, videoFile] = initializeSystem(p);

%% Start processing
h1=figure;
% Put figure on the top left corner
% Adjust size for optimal viewing. Remove toolbars
% Note the original size is 1080 x 1920
set(h1,'Position',[606   393   835   464], 'Toolbar','None', 'Menubar','None');     
frameCount = 0;

h0=figure;
set(h0,'Position',[1   587   480   270], 'Toolbar','None', 'Menubar','None');   

h2=figure;
set(h2,'Position',[1   294   480   270], 'Toolbar','None', 'Menubar','None');

% Read first frame 
frame = readFrame(obj.video);
% Initialize the previous and next frames
oldframe = zeros(size(frame));
nextframe = frame;
% Update framecount
frameCount = frameCount+1;

% Mark the pellet
% Please note pellet is marked only once
% Assumption: Pellet does not move. If pellet moves, video should not be used for analysis
disp('Mark the pellet in the displayed image');
h1=imdisplay(frame, h1, frameCount);
[position, centroid, img] = imageMark(frame, h1);
roi='Pellet';

fileName = saveImage(img, fullfile(obj.imageFolder, roi), [obj.savePrefix,'_',int2str(frameCount)]);
roiData = [roiData; ...
    struct('roi',roi,'position', position,'centroid',centroid,'imageFile',fileName,'frameCount',frameCount)];

% Mark the reference for marking velocity
disp('Mark a rectangle with a known height (reference for measuring velocity')
refPosition = getrect;
refLength = input('What is the real world height of this reference? (in cms)    ');
refPixelLength=refLength/refPosition(1,4);

% Keep saving
[matDir,matPrefix]=fileparts(videoFile);
save(fullfile(matDir,[matPrefix,'.mat']), 'roiData', 'grabResult', 'isTremorCase', 'videoFile','refPixelLength');

reply = 'y';
while ~strcmpi(reply,'x')
    h1=imdisplay(frame,h1, frameCount);
    if hasFrame(obj.video)
        % Read frame
        nextframe = readFrame(obj.video);
        h2=imdisplay(nextframe,h2,frameCount+1);
    else
        nextframe = [];
    end
    reply = 'y';
    while ~isempty(reply)
        roi='';
        outcome = '';
        menuindex = 0;
        figure(h1);
        reply = input(['Is there anything of interest?\n',...
        '1 => Paw\n',...
        '2 => Nose\n',...
        '3 => Other\n',...
        'Next image  - Press Enter\n',...
        'Exit        - Press X/x]    '],'s');
        if isempty(reply)|strcmpi(reply,'x')
            break;
        end
        % Call imageMark for the given frame to mark the object
        [position, centroid, img] = imageMark(frame, h1);
        switch reply
        case {'1'}
            roi='Paw';
            fileName = saveImage(img, fullfile(obj.imageFolder, roi), [obj.savePrefix,'_',int2str(frameCount)]);
            actionNum = '0';
            action = '';
            outcome = '';
            while ~isempty(actionNum)
                actionNum = input(['\nDo you wish to continue to next image [Enter]\n',...
                    'Or\nSpecify Event [Press 1 or 2 or 3] \n',...
                    '0 => Initialize\n',...
                    '1 => Cross Doorway\n',...
                    '2 => Reach\n',...
                    '3 => Grasp\n',...
                    '4 => Retrieve\n',...
                    '5 => Light On\n',...
                    '6 => Light Off\n'],'s');
                switch actionNum
                case '0'
                    action = 'Initialize';
                    % For special cases of Initialize, we do not have custom menus for
                    %   - Action type
                    %   - Consequence
                    % Hence, actionType = [], consequence = []
                    grabResult = [grabResult; ...
                        struct('action',action, 'actionType',[], 'consequence',[],...
                            'position',position,'centroid', centroid,'imageFile',fileName,'frameCount',frameCount)];
                    reply = '';
                case '1'
                    action = 'Cross Doorway';
                    % For special cases of Initialize, we do not have custom menus for
                    %   - Action type
                    %   - Consequence
                    % Hence, actionType = [], consequence = []
                    grabResult = [grabResult; ...
                        struct('action',action, 'actionType',[], 'consequence',[],...
                            'position',position,'centroid', centroid,'imageFile',fileName,'frameCount',frameCount)];
                    reply = '';
                case '2'
                    action = 'Reach';
                case '3'
                    action = 'Grasp';
                case '4'
                    action = 'Retrieve';
                case '5'
                    action = 'Light On';
                    % For special cases of Light On, we do not have custom menus for
                    %   - Action type
                    %   - Consequence
                    % Hence, actionType = [], consequence = []
                    grabResult = [grabResult; ...
                        struct('action',action, 'actionType',[], 'consequence',[],...
                            'position',position,'centroid', centroid,'imageFile',fileName,'frameCount',frameCount)];
                    reply = '';
                case '6'
                    action = 'Light Off';
                    % For special cases of Light Off, we do not have custom menus for
                    %   - Action type
                    %   - Consequence
                    % Hence, actionType = [], consequence = []
                    grabResult = [grabResult; ...
                        struct('action',action, 'actionType',[], 'consequence',[],...
                            'position',position,'centroid', centroid,'imageFile',fileName,'frameCount',frameCount)];
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
                    grabResult = [grabResult; ...
                        struct('action',action, 'actionType',actionType, 'consequence',consequence,'position',position,'centroid', centroid,'imageFile',fileName,'frameCount',frameCount)];
                    reply = '';
                end
            end
        case {'2'}
            roi='Nose';
        case {'3'}
            roi = lower(input('What do you wish to mark?    ','s'));
            roi = strrep(roi,' ','');
            savedir = fullfile(obj.imageFolder,roi);
            if ~isdir(savedir)
                mkdir(savedir);
            end
        otherwise
            roi = '';
            disp('Warning: You have marked an incorrect input. Please try again.')
        end
        if ~isempty(roi)
            fileName = saveImage(img, fullfile(obj.imageFolder, roi), [obj.savePrefix,'_',int2str(frameCount)]);
            roiData = [roiData; ...
                struct('roi',roi,'position', position,'centroid',centroid,'imageFile',fileName,'frameCount',frameCount)];
            save(fullfile(matDir,[matPrefix,'.mat']), 'roiData', 'grabResult', 'isTremorCase', 'videoFile','refPixelLength');
        end
    end

    oldframe = frame;
    h0=imdisplay(oldframe,h0,frameCount);

    if ~isempty(nextframe)
        frame = nextframe;
        frameCount = frameCount+1;
    else
        break;
    end
end
% tremorFlag = input('Did you notice tremor in the video? [Y | N]     ', 's');
% isTremorCase = lower(tremorFlag)=='y';

%% TODO Provide support for image files
% % Create imageDatastore from the raw images
% rawImageSet = imageDatastore(fpath, 'IncludeSubfolders', false,'LabelSource', 'foldernames');
% numRawImages = numel(rawImageSet.Files);
% for i = 1:numRawImages
%     % Read frame
%     img = readimage(rawImageSet, i);
%     % Call imageMarkSave for the given frame/image to mark object for classification
%     matchCount = imageMarkSave(img, matchCount);
%     contFlag = input('Do you wish to keep going? [Enter - Y | N]: ', 's');
%     if strcmpi(contFlag,'n')
%         break;
%     end
% end
[matDir,matPrefix]=fileparts(videoFile);
newMatDir = input(['Saving MAT file in "', matDir, '", Okay? [Enter - Yes | Any key - No]  '], 's');
if ~isempty(newMatDir)
    newMatDir = uigetdir(matDir, 'Pick a Directory');
end
if ~(isempty(newMatDir) | newMatDir == 0)
    matDir = newMatDir;
end

save(fullfile(matDir,[matPrefix,'.mat']), 'roiData', 'grabResult', 'isTremorCase', 'videoFile','refPixelLength');

analyzeThis = input('Do you wish to see if the mouse actions were marked correctly? [Yes - Enter]    ','s');
if isempty(analyzeThis)
    analyzeMouseAction(roiData, grabResult, videoFile, 'foreground', true);
end
return;

    %% Read input
    function p = readInput(input)
        p = inputParser;
        defaultVideoFile = '';
        defaultMode = 'default';
        defaultStandardImageSize = [64,64];
        defaultRawImageFolder = '';

        addParameter(p,'VideoFile',defaultVideoFile, @ischar);
        addParameter(p,'Mode',defaultMode, @ischar);
        addParameter(p,'StandardImageSize',defaultStandardImageSize, @isinteger);

        %% TODO Provide support for image files
        % addParameter(p,'RawImageFolder',defaultRawImageFolder, @ischar);

        parse(p, input{:});
    end

    %% Initialize and setup system objects and outputs
    function [obj, roiData, grabResult, isTremorCase, videoFile] = initializeSystem(p)

        % Get folder where the training images are stored
        disp('Select video for marking mouse grabs (*.mp4, *.avi, *.mov)');
        if isempty(p.Results.VideoFile)
            [fileName, fpath] = uigetfile({'*.mp4;*.avi;*.mov', 'Select video for marking mouse grabs (*.mp4, *.avi, *.mov)'});
            videoFile = fullfile(fpath, fileName);
            [~, obj.savePrefix] = fileparts(fileName);
        else
            videoFile = p.Results.VideoFile;
            [fpath, obj.savePrefix] = fileparts(videoFile);
        %% TODO Provide support for image files
        % elseif ~isempty(p.Results.RawImageFolder)
        %     rawImageFolder = p.Results.RawImageFolder;
        %     fpath = rawImageFolder;
        %     obj.savePrefix = '';
        
        end

        if ~isempty(videoFile)
            % Read video file
            obj.video = VideoReader(videoFile);
        else
            error('Could not find video. Please check and try again');
        end

        obj.standardImageSize = int16(p.Results.StandardImageSize);

        %% Initialize
        % Prepare folders for storing matches
        %   - Pellet
        %   - Paw
        %   - Nose
        folderTypes = {'Pellet', 'Paw', 'Nose'};
        obj.imageFolder = fullfile(fpath,'matches');
        for i = 1:length(folderTypes)
            savedir = fullfile(obj.imageFolder,folderTypes{i});
            if ~isdir(savedir)
                mkdir(savedir);
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

        obj.imgMatch = zeros(obj.standardImageSize);

        % Initialize outputs
        roiData = struct([]);
        grabResult = struct([]);
        isTremorCase = logical(0);
    end

    % For the given frame/image, ask the user to identify
    % and mark objects
    % Return position and and the marked image (standard size)
    function [position, centroid, imgMatch] = imageMark(img, h)
        if nargin>=2
            % Bring image to forefront
            figure(h);
        end
        % Ask user to draw rectangle to mark object
        position = int16(getrect);
        % Get marked image (size as marked)
        imgMarked = getImageMarked(img, position);
        
        %% Now we will select a region of standard image size (def 64 x 64) around
        % the centroid of the marked region and save this
        
        %% Binarize the marked image
        imgBin = imbinarize(rgb2gray(imgMarked));

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%TODO: Refraining from using regionpros because the images were not uniformally lit
        %       Single image was showing up as multiple objects with different centroids.
        %       For now, going with center as the centroid
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % %% Extract the centroid (if marked properly, there should be only one centroid,
        % % i.e. [x y] coordinates of the centroid of the marked image
        % % regionprops returns a structure as imageProp.Centroid relative to the marked image
        % imageProp = regionprops(imgBin,'centroid'); 
        % centroids = int16(cat(1, imageProp.Centroid)); % Convert the structure to an array of int
        % % If more than one centroid is detected, choose the centroid that is closest to the 
        % % center of the select image [size(imgBin)/2]
        % centroids = centroids((size(imgBin,1)/2-centroids(:,1)).^2+(size(imgBin,2)/2-centroids(:,2)).^2 == min((size(imgBin,1)/2-centroids(:,1)).^2+(size(imgBin,2)/2-centroids(:,2)).^2), :);
        % % When there is a single centroid, above function returns a row vector as required
        % % When there multiple centroids, even though the above returns the correct centroid location,
        % %   it returns it as a column vector. Convert by default to row vector as required
        % % TODO Check why sometimes length(centroids)~=2. For now, continue
        % if length(centroids)~=2
        %     disp(imageProp);
        %     disp(size(imgBin,1));
        %     centroid=[];
        %     imgMatch=[];
        %     return;
        % end
        % centroid=reshape(centroids,[1 2]); 

        centroid = int16(size(imgBin)/2);

        %% Calculated position of region wrt original image
        % 1. Calculate location of centroid wrt original image
        %   centroids = centroids + position(1:2);          
        % 2. Then mark the top left corner of 100 x 100 region around centroid
        %   position(1:2) = [centroids(1)-50, centroids(2)-50];
        % 3. Then finally mark the width and height of the 100 x 100 region
        %   position(3:4) = [100 100];
        position = [[centroid + position(1:2) - int16(obj.standardImageSize/2)],obj.standardImageSize];
        % Position of centroid with respect to this standard size image is the center of the image
        centroid=int16(obj.standardImageSize/2);
        % Get marked image (standard image size around marked image centroid)
        imgMatch = getImageMarked(img, position);
    end

    function fileName = saveImage(img, fpath,fprefix)
        if ~isempty(img)
            fileName = fullfile(fpath, [fprefix,'.tiff']);
            %% Write image
            imwrite(img, fileName, 'TIFF');
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