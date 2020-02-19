"""Deprecated. Do not use."""
function [r,theta,diffXY,refCentroid,pawCentroid,traceVideoFile] = analyzeMouseAction(roiData, grabResult, videoFile, modeFlag, writeFrameCount)
% [r,theta,diffXY,refCentroid,pawCentroid,traceVideoFile] = analyzeMouseAction(roiData, grabResult, videoFile, modeFlag);
% -------------Outputs --------------
%   - r             : Absolute distance of paw from pellet
%   - theta         : Angle of approach of paw from pellet with respect to horizontal axis
%   - diffXY        : Difference between paw position and pellet position
%   - actionSpec    : Outcome for the marked position (empty if mouse was still attempting and did not grab)
%                     struct('action','actionType','consequence')
%   - traceVideoFile: Filenames of the output trace videos
%   - refCentroid   : Absolute pellet center in original video
%   - pawCentroid   : Absolute paw center in original video
%
% -------------- Usage --------------
%
% [...] = analyzeMouseAction(roiData, grabResult, videoFile, modeFlag);
%
% -------------- Inputs --------------
% Provide necessary inputs. Please maintain structure as follows
%   - roiData:          Position of the selection by user for paw, pellet, node, etc.  
%                       Structure with fields ('roi','position','centroid',imageFile','frameCount')
%                       where roi is one of (paw, pellet, node, ...)
%   - grabResult:       The outcome of the grab:
%                       * Overreach
%                       * Underreach
%                       * Prehension (user suggested label for prehension)
%                       Structure with fields ('outcome','position','centroid','imageFile','frameCount')
%   - videoFile:        original video file location (string)
%   - modeFlag:         Process in 'foreground' (show videos and plots) or
%   'background-video' (only save with videos) or 'background' (only data -
%   no videos)
%
%%%%% See markMouseAction.m for further reference %%%%

% Initialize settings
bbox_flag = false;  % No box around the marked positions; No labels

% Initialize Outputs
r           = [];
theta       = [];
diffXY      = [];
refCentroid = [];
pawCentroid = [];
traceVideoFile = '';
if strcmpi(modeFlag, 'background-video') | strcmpi(modeFlag, 'foreground')
    % Video Sizes
    actualVidSize = [1080 1920 3];                                      % RGB image of 1080x1920
    displayResizeFactor = 2.5;                                          % For display, resize images
    displayVidSize = [ceil(actualVidSize(1:2)/displayResizeFactor), 3]; % RGB image of 720x1280
    % Size the atari box size (paw and pellet)
    boxSize = 5;
    % Init the pellet atari to green
    pelletBoxColor = zeros(boxSize*2+1,boxSize*2+1,3);
    pelletBoxColor(:,:,2) = 255; % Green
    % Init the paw atari to red
    pawBoxColor = zeros(boxSize*2+1,boxSize*2+1,3);
    pawBoxColor(:,:,1) = 255; % Red
    % Init the trace
    traceSize = 2;
    % Init the trace atari to yellow
    traceBoxColor = zeros(traceSize*2+1,traceSize*2+1,3);
    traceBoxColor(:,:,1:2) = 255; % Yellow
    frameRate = 4;
    % Init config for writing frame number to video
    frameCountWriteFlag = writeFrameCount;
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

    newsavedir = input(['Saving video/trace files in "', savedir, '", Okay? [Enter - Yes | Any key - No]  '], 's');
    if ~isempty(newsavedir)
        newsavedir = uigetdir(savedir, 'Pick a Directory');
    end
    if ~(isempty(newsavedir) | newsavedir == 0)
        savedir = newsavedir;
    end

    % Init the video reader
    % Sometimes the video may have been moved to a different location
    % If the videoFile doesn't exist, return error
    if isempty(dir(videoFile))
        error(['Warning: Could not find the video file - ' videoFile]);
    end
    % Check if appropriate video file has been provided
    [pathName,vidName,vidExt] = fileparts(videoFile);
    if isempty(vidExt) | ~(strcmpi(vidExt, '.mp4') | strcmpi(vidExt, '.avi')| strcmpi(vidExt, '.mov')| strcmpi(vidExt, '.mts'))
        error('You have not provided appropriate video file. Please locate the original video and try again');
    end

    videoReader = vision.VideoFileReader(videoFile);

    % Init the foreground detector (mask)
    maskDetector = vision.ForegroundDetector();     % Using default parameters

    % Init video writers
    traceVideoFile{1}=fullfile(savedir, [savePrefix,'_ContinuousTrace.mp4']);
    traceVideoWriter    = vision.VideoFileWriter(traceVideoFile{1}, 'FrameRate', frameRate, 'FileFormat', 'MPEG4');
    traceVideoFile{2}=fullfile(savedir, [savePrefix,'_Trace.mp4']);
    atariVideoWriter    = vision.VideoFileWriter(traceVideoFile{2}, 'FrameRate', frameRate, 'FileFormat', 'MPEG4');
    traceVideoFile{3}=fullfile(savedir, [savePrefix,'_VideoWTrace.mp4']);
    vwtVideoWriter     = vision.VideoFileWriter(traceVideoFile{3}, 'FrameRate', frameRate, 'FileFormat', 'MPEG4');
    traceVideoFile{4}=fullfile(savedir, [savePrefix,'_Mask.mp4']);
    maskVideoWriter     = vision.VideoFileWriter(traceVideoFile{4}, 'FrameRate', frameRate, 'FileFormat', 'MPEG4');
end

if strcmpi(modeFlag,'foreground')
    %% Init the video players
    % Atari Video - Square boxes to denote objects
    atariPlayer = vision.VideoPlayer('Position', [20, 400, displayVidSize(2), displayVidSize(1)]);

    % Actual Video with Trace
    vwtPlayer = vision.VideoPlayer('Position', [740, 400, displayVidSize(2), displayVidSize(1)]);

    % Mask Video - Actual marked objects shown as black and white
    maskPlayer = vision.VideoPlayer('Position', [740, 20, displayVidSize(2), displayVidSize(1)]);
end


%% Start processing
if isempty(grabResult)
    warning('Processing file with no grabs. Returning empty!')
    return
end

% Get the centroid and bbox of the pellet
[refCentroid, refBox] = getBox(roiData,'Pellet');

% Get the centroid and bbox of the paw
[pawCentroid, pawBox, pawFrames] = getBox(roiData, 'Paw');

% Original axes had top-left corner as (0,0)
% Change axes so that pellet is reference is at the bottom
% Get diffXYerence between reference (pellet) and paw
diffXY = pawCentroid-refCentroid;
% Adjust y-axis so that pellet reference is bottom
diffXY(:,2)=-diffXY(:,2);

% Calculate distance
r = sqrt(sum(power(diffXY,2),2));
theta = atan(diffXY(:,1)./diffXY(:,2))*180/pi;

if strcmpi(modeFlag,'foreground')
    h = plotPawTrajectory(diffXY, r, theta);
end

if strcmpi(modeFlag,'foreground') | strcmpi(modeFlag,'background-video')
    %% Save video
    % Init the mask and the atari base images
    mask   = uint8(zeros(1080,1920,3));
    atari   = uint8(zeros(1080,1920,3));
    ctrace  = uint8(zeros(1080,1920,3));
    vwt     = uint8(zeros(1080,1920,3));
    bbox    = [];
    outcome = {};
    actionSpec = {};
    for i = 1:pawFrames(end)
        % We are using the original video to superimpose to the grab
        % We go through every frame of the original video
        frame = videoReader.step();

        %% Create the atari image
        % Reset the image
        atari = uint8(zeros(1080,1920,3));
        % Write the pellet as green
        atari(refCentroid(1,2)-boxSize:refCentroid(1,2)+boxSize,refCentroid(1,1)-boxSize:refCentroid(1,1)+boxSize,:)=pelletBoxColor;

        %% Create the video with trace image
        % Reset the image
        vwt = frame;
        if frameCountWriteFlag
            vwt = insertText(vwt, [ceil(size(vwt,2)-(frameCountWriteCharWidth*ceil(log10(i))+frameCountWriteBoxHorzPadding)-frameCountWritePadding) (frameCountWriteFontSize+frameCountWriteBoxVertPadding+frameCountWritePadding)], i, 'Font', frameCountWriteFont, 'FontSize', frameCountWriteFontSize, 'AnchorPoint', 'Center', 'TextColor', frameCountWriteTextColor, 'BoxColor',frameCountWriteBoxColor);
        end
        % Write the pellet as green
        vwt(refCentroid(1,2)-boxSize:refCentroid(1,2)+boxSize,refCentroid(1,1)-boxSize:refCentroid(1,1)+boxSize,:)=pelletBoxColor;

        %% Create the mask image
        % Reset the image
        mask    = uint8(zeros(1080,1920,3));
        % Detect mask foreground as binarized image (0,1)
        maskBin = maskDetector.step(frame);
        % Apply morphological operations to remove noise and fill in holes.
        maskBin = imopen(maskBin, strel('rectangle', [3,3]));
        % Save to mask image in rgb
        [maskX,maskY]   = find(maskBin);
        for k = 1:length(maskX)
            mask(maskX(k),maskY(k),:)=255;  % TODO: Find a better way to do this
        end
        % Write the pellet as green
        mask(refCentroid(1,2)-boxSize:refCentroid(1,2)+boxSize,refCentroid(1,1)-boxSize:refCentroid(1,1)+boxSize,:)=pelletBoxColor;

        %% Mark the paw in the video
        % But the marking may not have been done on every frame
        % So we add the paw only if the frame has been marked
        loc=find(i>=pawFrames); % Get the index of the saved markings uptil current frame

        if ~isempty(loc) & ~isempty(pawCentroid(loc(end))) 
            %% NOTE: Additional Checking For ~isempty(pawCentroid(loc(end)))
            % This is because at times marking the paw may not have worked and getBox returns empty
            % See sub-function imageMark in markMouseAction where check for length(centroids)~=2

            % Get the latest frame wrt index of the saved markings
            % This is  index 'i' if marking has been done for 'i',
            % else it is the previous frame where marking has been done
            curidx = loc(end);
            % Write the paw as red
            atari(pawCentroid(curidx,2)-boxSize:pawCentroid(curidx,2)+boxSize,pawCentroid(curidx,1)-boxSize:pawCentroid(curidx,1)+boxSize,:)=pawBoxColor;
            % Write the trace as yellow
            ctrace(pawCentroid(curidx,2)-traceSize:pawCentroid(curidx,2)+traceSize,pawCentroid(curidx,1)-traceSize:pawCentroid(curidx,1)+traceSize,:)=traceBoxColor;
            % Write the paw as red
            vwt(pawCentroid(curidx,2)-boxSize:pawCentroid(curidx,2)+boxSize,pawCentroid(curidx,1)-boxSize:pawCentroid(curidx,1)+boxSize,:)=pawBoxColor;
            % TODO Mark trajectory as yellow
            % for j = loc
            %     vwt(pawCentroid(j,2)-2:pawCentroid(j,2)+2,pawCentroid(j,1)-2:pawCentroid(j,1)+2,:)=traceBoxColor;
            % end

            % Mark the paw in the mask
            % Write the paw as red
            mask(pawCentroid(curidx,2)-boxSize:pawCentroid(curidx,2)+boxSize,pawCentroid(curidx,1)-boxSize:pawCentroid(curidx,1)+boxSize,:)=pawBoxColor;
            if isempty(grabResult)
                match   = [];
            else
                match = find(i ==[grabResult(:).frameCount]);
            end
            if ~isempty(match)
                % if there is a coinciding marked action (reach, grasp, retrieve), then mark the action & action outcome
                % If there are multiple actions marked for the same frame, in the video show only the first one marking
                % outcome = [outcome;{[int2str(match(1)),': ',grabResult(match(1)).action,'-',grabResult(match(1)).actionType]}];
                % bbox    = [bbox;[grabResult(match(1)).position]];
                % outcome = [{[int2str(match(1)),': ',grabResult(match(1)).action,'-',grabResult(match(1)).actionType]}];
                outcome = [{[int2str(match(1)),': ',grabResult(match(1)).action]}];
                bbox    = [[grabResult(match(1)).position]];

             %    % If there are multiple actions marked for the same frame, save all actions
             %    actionCell = struct2cell(grabResult(match));
             %    % Only need to save the first 3 elements of the cell
             %    % Note: Strucure is important. Assumption action, actionType,
             %    % consequence are the first 3 elements of the structure
             %    % TODO: Remove dependence on fixed structure
             %    actionCell = actionCell(1:3,:);
             %    actionSpec{curidx,1} = actionCell;
             % else
             %    actionSpec{curidx,1} = {};
            end
        end
        if ~isempty(bbox) & bbox_flag
            % Mark the actions on the videos
            atari   = insertObjectAnnotation(atari, 'rectangle', bbox, outcome);
            mask    = insertObjectAnnotation(mask, 'rectangle', bbox, outcome);
            vwt     = insertObjectAnnotation(vwt, 'rectangle', bbox, outcome);
        end
        if strcmpi(modeFlag,'foreground')
            atariPlayer.step(imresize(atari,1/displayResizeFactor));
            vwtPlayer.step(imresize(vwt,1/displayResizeFactor));
            maskPlayer.step(imresize(mask,1/displayResizeFactor));
            pause(1/frameRate);
        end
        step(atariVideoWriter, atari);
        step(traceVideoWriter, ctrace);
        step(maskVideoWriter, mask);
        step(vwtVideoWriter, vwt);

    end
    release(atariVideoWriter);
    release(traceVideoWriter);
    release(maskVideoWriter);
    release(vwtVideoWriter);
    videoFile=traceVideoFile;
end

    %% For the given box, [x y width height], return the selected image with actual
    % coordinates [row(1):row(end), column(1):column(end)]
    function imgMarked = getImageMarked(img, position)
        imgMarked = img(position(2):position(2)+position(4)-1, position(1):position(1)+position(3)-1,:);
    end

    %% From the marked region of interest data (roiData), retrieve all the centroids and bbox data
    % as well as corresponding frame info for a given object of interest ('Paw', 'Pellet')
    function [centroid, bbox, frameCount] = getBox(roiData, objType)
        % [centroid, bbox, frameCount] = getBox(roiData, objType)

        % Initialize
        centroid    = [];
        bbox        = [];
        frameCount  = [];
        % Get a list of all the objects that were marked in the video
        roiMarked   = {roiData.roi}';
        % Get index of the particular object of interest ('Paw', 'Pellet')
        objIdx      = strcmpi(objType,roiMarked);
        if sum(objIdx)==0
            warning([objType ' not found, Returning empty centroid and bbox']);
            return
        end
        
        % Retrieve all centroid, bbox, framecount data
        offset      = double(cat(1, roiData.centroid));
        pos         = double(cat(1, roiData.position));
        frameCount  = double(cat(1, roiData.frameCount));
        % Select only those that belong to the object of interest
        offset      = offset(1,:); % Hack for now. For some reason offset length is coming one less at times   
        pos         = pos(objIdx,:);
        frameCount  = frameCount(objIdx,:);
        % Add relative centroid of the bbox to the absolute location to calculate absolute position of centroid
        centroid    = pos(:,1:2)+offset(1,1:2); 
        bbox        = pos;
    end
end