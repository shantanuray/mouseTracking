function [r, theta, diffXY, refXYPosition, roiXYPosition, roiFrames, traceVideoFile] = analyzeMouseAnnotation(roiData, reachingEvents, videoFile, varargin)
% [r,theta,diffXY,refXYPosition,roiXYPosition,traceVideoFile] = analyzeMouseAction(roiData, reachingEvents, videoFile);
% -------------Outputs --------------
%   - r             : Absolute distance of roi from ref
%   - theta         : Angle of approach of roi from ref with respect to horizontal axis
%   - diffXY        : Difference between roi position and ref position
%   - actionSpec    : Outcome for the marked position 
%                     (empty if mouse was still attempting and did not grab)
%                     struct('action','actionType','consequence')
%   - traceVideoFile: Filenames of the output trace videos
%   - refXYPosition   : Pellet position in original video
%   - roiXYPosition   : ROI marking - body part center in original video
%
%
% -------------- Inputs --------------
% Provide necessary inputs. Please maintain structure as follows
%   - roiData:          (Mandatory) Position of the selection by user for target (pellet) and 
%                       regions of interest such as 'hand', 'wrist', 'nose', 'littlefinger', 'index'
%                       See annotateMouseAction.m
%   - reachingEvents:   (Mandatory) Annotations of different events during the reaching task
%                       See annotateMouseAction.m
%   - videoFile:        (Mandatory) Original video file location (string)
%   - RefTargetName     Default - 'pellet'
%   - RefBodyPartName   Default - 'hand' 
%   - VideoMux:         logical array for whether a particular video type should me made, such as
%                       [false      false            true          true      ]
%                       [mask continuous_trace  normal_trace video_with_trace]
%                       Default: [false false true true]
%   - BoxLabel:         Add annotation labels (true, false - default)
%   - WriteFrameCount:  true or false (write frame count in video), Default true
%   - ModeFlag:         'foreground' (Default - show videos and plots) or
%                       'background-video' (only save with videos) or 
%                       'background' (only data - no videos)
% -------------- Usage --------------
% [...] = analyzeMouseAction(roiData, reachingEvents, '180LR.mov');
% [...] = analyzeMouseAction(roiData, reachingEvents, '180LR.mov',...
%            'RefTargetName', 'pellet', 'RefBodyPartName', 'hand');
% [...] = analyzeMouseAction(roiData, reachingEvents, '180LR.mov',...
%            'RefTargetName', 'pellet', 'RefBodyPartName', 'hand',... 
%            'BoxLabel', true, 'WriteFrameCount', false,...
%            'ModeFlag', 'background-video');
%%%%% See also annotateMouseAction.m %%%%

% Initialize settings
p = readInput(varargin);
[refTargetName,refBodyPartName,maskFlag,ctraceFlag,traceFlag,vwtFlag,bboxFlag,modeFlag,frameCountWriteFlag, actualVidSize,atariColor] = parseInput(p.Results);

% Initialize Outputs
r           = [];
theta       = [];
diffXY      = [];
refXYPosition = [];
roiXYPosition = [];
traceVideoFile = '';
if strcmpi(modeFlag, 'background-video') | strcmpi(modeFlag, 'foreground')
    % Video Sizes
    % actualVidSize = [1080 1920 3];                                      % RGB image of 1080x1920
    displayResizeFactor = 2.5;                                          % For display, resize images
    displayVidSize = [ceil(actualVidSize(1:2)/displayResizeFactor), 3]; % RGB image of 720x1280
    
    % To display the marked body part, use a box of predetermined size and color range
    % Size the atari box size (roi and ref)
    boxSize  = 5;   % 5 x 5
    if strcmpi(atariColor,'white')
        boxColors = ones(length(roiData.roi),3);
    else
        boxColors = distinguishable_colors(length(roiData.roi));
    end
    minLikelihood = roiData.minimumLikelihood;
    frameRate = 4;
    refROI = find(strcmpi(roiData.roi, refBodyPartName));
    refTarget = find(strcmpi(roiData.roi, refTargetName));
    if length(refROI) == 0; error('Check reference ROI name.'); end
    
    % Init config for writing frame number to video
    frameCountWriteFontSize = 32;
    frameCountWriteFont = 'Arial';
    frameCountWriteCharWidth = ceil(5*32/18);
    frameCountWriteBoxHorzPadding = ceil(7*32/18);
    frameCountWriteBoxVertPadding = 1;
    frameCountWriteCharHeight = frameCountWriteFontSize+2;
    frameCountWritePadding = 5;
    frameCountWriteTextColor = 'black';
    frameCountWriteBoxColor = 'white';

    % Location of saved video
    [savedir, savePrefix]=fileparts(videoFile);    

    % Init the video reader
    % Sometimes the video may have been moved to a different location
    % If the videoFile doesn't exist, return error
    if isempty(dir(videoFile))
        error(['Warning: Could not find the video file - ' videoFile]);
    end
    % Check if appropriate video file has been provided
    [pathName,vidName,vidExt] = fileparts(videoFile);
    if isempty(vidExt) | ~(strcmpi(vidExt, '.mp4') | strcmpi(vidExt, '.avi')| strcmpi(vidExt, '.mov')| strcmpi(vidExt, '.mts') | strcmpi(vidExt, '.m4v'))
        error('You have not provided appropriate video file. Please locate the original video and try again');
    end

    videoRef = VideoReader(videoFile);

    % Init the foreground detector (mask)
    % maskDetector = vision.ForegroundDetector();     % Using default parameters

    % Init video writers
    if ctraceFlag
        traceVideoFile{1}=fullfile(savedir, [savePrefix,'_ContinuousTrace.mp4']);
        ctraceVideoWriter    = vision.VideoFileWriter(traceVideoFile{1}, 'FrameRate', frameRate, 'FileFormat', 'MPEG4');
        % Init the continuous trace frame
        % Note: Only this image is initialized outside the video creation loop because it overlays
        %       each frame over the previous frames
        ctrace  = uint8(zeros(1080,1920,3));
    end
    if traceFlag
        traceVideoFile{2}=fullfile(savedir, [savePrefix,'_Trace.mp4']);
        atariVideoWriter    = vision.VideoFileWriter(traceVideoFile{2}, 'FrameRate', frameRate, 'FileFormat', 'MPEG4');
    end
    if vwtFlag
        traceVideoFile{3}=fullfile(savedir, [savePrefix,'_VideoWTrace.mp4']);
        vwtVideoWriter     = vision.VideoFileWriter(traceVideoFile{3}, 'FrameRate', frameRate, 'FileFormat', 'MPEG4');
    end
    if maskFlag
        traceVideoFile{4}=fullfile(savedir, [savePrefix,'_Mask.mp4']);
        maskVideoWriter     = vision.VideoFileWriter(traceVideoFile{4}, 'FrameRate', frameRate, 'FileFormat', 'MPEG4');
    end
end

if strcmpi(modeFlag,'foreground')
    newsavedir = input(['Saving video/trace files in "', savedir, '", Okay? [Enter - Yes | Any key - No]  '], 's');
    if ~isempty(newsavedir)
        newsavedir = uigetdir(savedir, 'Pick a Directory');
    end
    if ~(isempty(newsavedir) | newsavedir == 0)
        savedir = newsavedir;
    end
    %% Init the video players
    if traceFlag; atariPlayer = vision.VideoPlayer('Position', [20, 400, displayVidSize(2), displayVidSize(1)]); end;
    if vwtFlag; vwtPlayer = vision.VideoPlayer('Position', [740, 400, displayVidSize(2), displayVidSize(1)]); end;
    if maskFlag; maskPlayer = vision.VideoPlayer('Position', [740, 20, displayVidSize(2), displayVidSize(1)]); end;
end


%% Start processing
if isempty(reachingEvents)
    warning(['Processing file ', videoFile,' with no grabs!'])
% elseif strcmpi(modeFlag, 'foreground') | strcmpi(modeFlag, 'background-video')
%     jumpToFrame = reachingEvents(find(strcmpi({reachingEvents(:).action}, 'Initialize'))).frameCount;
%     if jumpToFrame > 1
%         frameCount = 1;
%         while frameCount < jumpToFrame
%             readFrame(videoRef);
%             frameCount = frameCount + 1;
%         end
%     end
end
jumpToFrame = 1;

% Get the centroid and bbox of the ref
refXYPosition = getBox(roiData, refTargetName);
refXYPosition= refXYPosition(1:2, 1);

% Get the centroid and bbox of the roi
[roiXYPosition, roiFrames] = getBox(roiData, refBodyPartName);

% Original axes had top-left corner as (0,0)
% Change axes so that ref is reference is at the bottom
% Get diffXYerence between reference (ref) and roi

if isempty(roiXYPosition)
    warning(['No markings in ', videoFile, '. Returning empty'])
    r = [];
    diffXY = [];
    theta = []; 
    roiFrames = [];
    traceVideoFile = '';
    return;
end

diffXY = roiXYPosition(1:2, :) - refXYPosition;
% Adjust y-axis so that ref reference is bottom
diffXY(2,:) = -diffXY(2,:);

% Calculate distance
r = sqrt(sum(power(diffXY,2),1));
theta = atan(diffXY(2, :)./diffXY(1, :))*180/pi;

if strcmpi(modeFlag, 'foreground')
    h = plotPawTrajectory(diffXY, r, theta);
end

if strcmpi(modeFlag, 'foreground') || strcmpi(modeFlag, 'background-video')
    %% Save video
    % mask   = uint8(zeros(1080,1920,3));
    bbox    = [];
    outcome = {};
    refTargetPaint = permute(repmat(repmat(uint8(255*boxColors(refTarget, :)), boxSize, 1), 1, 1, boxSize), [3, 1, 2]);
    for i = jumpToFrame:double(roiData.frameCount(end)) %roiFrames
        % We are using the original video to superimpose to the grab
        % We go through every frame of the original video
        try
            frame = readFrame(videoRef);
        catch ME
            disp(['Error: ', ME.identifier, ' for video ', videoFile])
            if traceFlag; step(atariVideoWriter, atari); end;
            if ctraceFlag; step(ctraceVideoWriter, ctrace); end;
            if vwtFlag; step(vwtVideoWriter, vwt); end;
            if maskFlag; step(maskVideoWriter, mask); end;
            break;
        end

        %% Get the markings of the roi in the video
        marking = roiData.marking(:, i); % (x,y, likelihood) for all markings as a single row
        if traceFlag %% Create the trace image
            % Reset the image (atari video only has the current frame marking)
            atari = uint8(zeros(1080,1920,3));
            % Render the target object ('pellet') as box color #1 (refTarget)
            atari(int16(refXYPosition(2)-(boxSize-1)/2:refXYPosition(2)+(boxSize-1)/2),... 
                int16(refXYPosition(1)-(boxSize-1)/2:refXYPosition(1)+(boxSize-1)/2), :) = refTargetPaint;
            % Render the roi markings
            atari = renderMarking(atari, marking, roiData.roi);
            %atari = renderText(atari, num2str(i));
        end
        if vwtFlag % Create the video with overlay of the markings on original video
            % Reset the image (vwt video only has the current frame marking)
            vwt = frame;
            % Render the target object ('pellet') as box color #1 (refTarget)
            vwt(int16(refXYPosition(2)-(boxSize-1)/2:refXYPosition(2)+(boxSize-1)/2),...
                int16(refXYPosition(1)-(boxSize-1)/2:refXYPosition(1)+(boxSize-1)/2), :) = refTargetPaint;
            % Render the roi markings
            vwt = renderMarking(vwt, marking, roiData.roi);
            vwt = renderText(vwt, num2str(i));
            vwt = vwt(1: size(frame, 1), 1: size(frame, 2), 1: size(frame, 3));
        end

        if ctraceFlag; ctrace = renderMarking(ctrace, marking, roiData.roi); end;

        if maskFlag % Create the mask image
            % Reset the image
            mask    = uint8(zeros(1080,1920,3));
            % Detect mask foreground as binarized image (0,1)
            maskBin = maskDetector.step(frame);
            % Apply morphological operations to remove noise and fill in holes.
            maskBin = imopen(maskBin, strel('rectangle', [3,3]));
            % Save to mask image in rgb
            [maskX, maskY]   = find(maskBin);
            for k = 1:length(maskX)
                mask(maskX(k), maskY(k),:)=255;  % TODO: Find a better way to do this
            end
            % Render the target object ('pellet') as box color #1 (refTarget)
            mask(int16(refXYPosition(2)-(boxSize-1)/2:refXYPosition(2)+(boxSize-1)/2),...
                int16(refXYPosition(1)-(boxSize-1)/2:refXYPosition(1)+(boxSize-1)/2), :) = refTargetPaint;
            % Render the roi markings
            mask = renderMarking(mask, marking, roiData.roi);
            %mask = renderText(mask, num2str(i));
        end

        if isempty(reachingEvents)
            match   = [];
        else
            match = find(i ==[reachingEvents(:).frameCount]);
        end
            
        if ~isempty(match)
            % if there is a coinciding marked action (reach, grasp, retrieve), then mark the action & action outcome
            % If there are multiple actions marked for the same frame, in the video show only the first one marking
            % outcome = [outcome;{[int2str(match(1)),': ',reachingEvents(match(1)).action,'-',reachingEvents(match(1)).actionType]}];
            % bbox    = [bbox;[reachingEvents(match(1)).position]];
            % outcome = [{[int2str(match(1)),': ',reachingEvents(match(1)).action,'-',reachingEvents(match(1)).actionType]}];
            outcome = [{[int2str(match(1)),': ',reachingEvents(match(1)).action]}];
            bbox    = int16([reachingEvents(match(1)).marking((refROI-1)*3+[1:2])',... 
                boxSize,...
                boxSize]);
        end
        
        if ~isempty(bbox) & bboxFlag
            % Mark the actions on the videos
            if traceFlag; atari = insertObjectAnnotation(atari, 'rectangle', bbox, outcome); end;
            % if ctraceFlag; ctrace = insertObjectAnnotation(ctrace, 'rectangle', bbox, outcome); end;
            if vwtFlag; vwt = insertObjectAnnotation(vwt, 'rectangle', bbox, outcome); end;
            if maskFlag; mask = insertObjectAnnotation(mask, 'rectangle', bbox, outcome); end;
        end
        if strcmpi(modeFlag,'foreground')
            if traceFlag; atariPlayer.step(imresize(atari,1/displayResizeFactor)); end;
            if vwtFlag; vwtPlayer.step(imresize(vwt,1/displayResizeFactor)); end;
            % pause(1/frameRate);
        end
        if traceFlag; step(atariVideoWriter, atari); end;
        if ctraceFlag; step(ctraceVideoWriter, ctrace); end;
        if vwtFlag; step(vwtVideoWriter, vwt); end;
        if maskFlag; step(maskVideoWriter, mask); end;

    end
    if traceFlag; release(atariVideoWriter); end;
    if ctraceFlag; release(ctraceVideoWriter); end;
    if vwtFlag; release(vwtVideoWriter); end;
    if maskFlag;  release(maskVideoWriter); end;
end
return;

    %% Render all the markings
    function frame = renderMarking(frameUnmarked, marking, roi)
        frame = frameUnmarked;
        frameSize = size(frame);
        % Please note minLikelihood, boxColors, boxSize are being accessed from calling function
        % Render the marking as a box of size boxSize x boxSize in frame with color chosen from bodyBoxColors
        % TODO Take care of points on the edge where boxSize will be outside the edge of image
        for bp = 1:length(roi) % Number of body parts = marking/3 for (x, y, likelihood)
            if marking((bp-1)*3+3) >= minLikelihood
                % boxPaint is a matrix of size (boxSize x boxSize) with value = (rgb) from boxColors 
                %   (eg. 5x5x3 if boxSize = 5)
                boxPaint = permute(repmat(repmat(uint8(255*boxColors(bp, :)), boxSize, 1), 1, 1, boxSize), [3, 1, 2]);
                frame(int16(max(marking((bp-1)*3+2)-(boxSize-1)/2, 1):max(marking((bp-1)*3+2)-(boxSize-1)/2, 1)+(boxSize-1)), ...
                    int16(max(marking((bp-1)*3+1)-(boxSize-1)/2, 1):max(marking((bp-1)*3+1)-(boxSize-1)/2, 1)+(boxSize-1)), :) =...
                boxPaint;
            end
        end
    end
    %% Render text at assigned position
    function frame = renderText(frameUnmarked, str)
        frame = frameUnmarked;
        if frameCountWriteFlag
            frame = insertText(frame,...
                [ceil(size(vwt,2)-(frameCountWriteCharWidth*ceil(log10(i))+frameCountWriteBoxHorzPadding)-frameCountWritePadding),...
                (frameCountWriteFontSize+frameCountWriteBoxVertPadding+frameCountWritePadding)],... 
                str,... 
                'Font', frameCountWriteFont,... 
                'FontSize', frameCountWriteFontSize,...
                'AnchorPoint', 'Center',... 
                'TextColor', frameCountWriteTextColor,... 
                'BoxColor',frameCountWriteBoxColor);
        end
    end
    %% From the marked region of interest data (roiData), retrieve all the (x,y) position
    % as well as corresponding frame info for a given object of interest ('Paw', 'Pellet')
    function [pos, frameCount] = getBox(roiData, roiType)
        % [pos, frameCount] = getBox(roiData, roiType)

        % Initialize
        pos         = [];
        frameCount  = [];
        % Get a list of all the objects that were marked in the video
        roiMarked   = roiData.roi;
        % Get index of the particular object of interest ('Paw', 'Pellet')
        roiIdx      = find(strcmpi(roiType, roiMarked));
        if isempty(roiIdx)
            warning([roiType ' not found']);
            return
        end
        
        % Retrieve all (x,y) position, frame count data
        frameCount  = find(roiData.marking((roiIdx-1)*3+3, :) >= roiData.minimumLikelihood);
        pos         = roiData.marking((roiIdx-1)*3 + [1:2], frameCount);
    end

    function h = plotPawTrajectory(diffXY, r, theta)
        % h = plotPawTrajectory(diffXY, r, theta)
        % Plot r and theta
        h = figure;
        set(h,'Position',[1 1 900 300]);
        h1=subplot(1,4,1);
        plot(1:length(r),r,'-r')
        ylabel(h1,'Distance from pellet')
        xlabel(h1,'Frames')
        h2=subplot(1,4,2);
        plot(1:length(r),theta,'-b')
        ylabel(h2,'Approach angle (degrees)')
        xlabel(h2,'Frames')
        h3=subplot(1,4,3);
        plot(diffXY(1, :),diffXY(2, :))
        ylabel(h3,'Approach - Y')
        xlabel(h3,'Approach - X')
        h3=subplot(1,4,4);
        plot(theta,r)
        ylabel(h3,'Approach - Distance')
        xlabel(h3,'Approach - Theta')
    end

    %% Read input
    function p = readInput(input)
        %   - RefTargetName     Default - 'pellet'
        %   - RefBodyPartName   Default - 'hand' 
        %   - VideoMux:         Default -  [false false true true]
        %   - BoxLabel          Default - false
        %   - ModeFlag:         Default - 'foreground'
        %   - WriteFrameCount:  Default true
        %   - ActualVidSize:    Default - [1080 1920 3]
        p = inputParser;
        defaultRefTargetName = 'pellet';
        defaultRefBodyPartName = 'hand';
        defaultVideoMux = [false false true true];
        defaultBoxLabel = false;
        defaultModeFlag = 'foreground';
        defaultWriteFrameCount = true;
        defaultActualVidSize = [1080 1920 3];
        defaultAtariColor = 'distinguishable_colors';
        
        addParameter(p,'RefTargetName',defaultRefTargetName, @ischar);
        addParameter(p,'RefBodyPartName',defaultRefBodyPartName, @ischar);
        addParameter(p,'VideoMux',defaultVideoMux, @islogical);
        addParameter(p,'BoxLabel',defaultBoxLabel, @islogical);
        addParameter(p,'ModeFlag',defaultModeFlag, @ischar);
        addParameter(p,'WriteFrameCount',defaultWriteFrameCount, @islogical);
        addParameter(p,'ActualVidSize',defaultActualVidSize, @isnumeric);
        addParameter(p,'AtariColor',defaultAtariColor, @ischar);
        parse(p, input{:});
    end

    function [refTargetName,refBodyPartName,maskFlag,ctraceFlag,traceFlag,vwtFlag,bboxFlag,modeFlag,frameCountWriteFlag, actualVidSize, AtariColor] = parseInput(p)
        refTargetName = p.RefTargetName;
        refBodyPartName = p.RefBodyPartName;
        videoMux = num2cell(p.VideoMux);
        [maskFlag, ctraceFlag, traceFlag, vwtFlag] = deal(videoMux{:});
        bboxFlag = p.BoxLabel;
        modeFlag = p.ModeFlag;
        frameCountWriteFlag = p.WriteFrameCount;
        actualVidSize = p.ActualVidSize;
        atariColor = p.AtariColor;
    end
end