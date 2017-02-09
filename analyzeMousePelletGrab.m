function [r,theta,diffXY,grabType,refCentroid,pawCentroid,traceVideoFile] = analyzeMousePelletGrab(roiData, grabResult, videoFile, modeFlag)
% [r,theta,diffXY,outcome,refCentroid,pawCentroid,traceVideoFile] = analyzeMousePelletGrab(roiData, grabResult, videoFile, modeFlag);
% -------------Outputs --------------
%   - r             : Absolute distance of paw from pellet
%   - theta         : Angle of approach of paw from pellet with respect to horizontal axis
%   - diffXY        : Difference between paw position and pellet position
%   - grabType      : Outcome for the marked position (empty if mouse was still attempting and did not grab)
%   - traceVideoFile: Filenames of the output trace videos
%   - refCentroid   : Absolute pellet center in original video
%   - pawCentroid   : Absolute paw center in original video
%
% -------------- Usage --------------
% [r,theta,diffXY,outcome] = analyzeMousePelletGrab;
% User will be asked to load a previously saved .mat file with the necessary inputs
%
% [r,theta,diffXY,outcome] = analyzeMousePelletGrab(roiData, grabResult, videoFile, modeFlag);
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
%   - modeFlag:         Process in 'foreground' (show videos and plots) or in 'background' (only save)
%
%%%%% See markMousePelletGrab.m for further reference %%%%


% Initialize
if nargin<4
    fileName='';
    while isempty(fileName)
        [fileName, pathName] = uigetfile( ...
               {'*.mat','MAT-files (*.mat)'}, ...
                'Pick the Mouse Paw-Grasp raw data file', ...
                'MultiSelect', 'off');
        load(fullfile(pathName,fileName),'pelletPosition','pawPosition','grabResult','videoFile');
        modeFlag = 'foreground';
    end
end
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

% Location of saved video
[savedir, savePrefix]=fileparts(videoFile);

% Init the video reader
videoReader = vision.VideoFileReader(videoFile);

% Init the foreground detector (mask)
maskDetector = vision.ForegroundDetector();     % Using default parameters

% Init video writers
traceVideoFile{1}=fullfile(savedir, [savePrefix,'_Trace.mp4']);
atariVideoWriter    = vision.VideoFileWriter(traceVideoFile{1}, 'FrameRate', frameRate, 'FileFormat', 'MPEG4');
traceVideoFile{2}=fullfile(savedir, [savePrefix,'_VideoWTrace.mp4']);
vwtVideoWriter     = vision.VideoFileWriter(traceVideoFile{2}, 'FrameRate', frameRate, 'FileFormat', 'MPEG4');
traceVideoFile{3}=fullfile(savedir, [savePrefix,'_Mask.mp4']);
maskVideoWriter     = vision.VideoFileWriter(traceVideoFile{3}, 'FrameRate', frameRate, 'FileFormat', 'MPEG4');

if strcmpi(modeFlag,'foreground')
    %% Init the video players
    % Atari Video - Square boxes to denote objects
    atariPlayer = vision.VideoPlayer('Position', [20, 400, 700, 400]);

    % Actual Video with Trace
    vwtPlayer = vision.VideoPlayer('Position', [740, 400, 700, 400]);

    % Mask Video - Actual marked objects shown as black and white
    maskPlayer = vision.VideoPlayer('Position', [740, 20, 700, 400]);
end


%% Start processing
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

%% Save video
% Init the mask and the atari base images
mask   = uint8(zeros(1080,1920,3));
atari   = uint8(zeros(1080,1920,3));
vwt     = uint8(zeros(1080,1920,3));
bbox    = [];
outcome = {};
grabType= {};
for i = 1:pawFrames(end)
    % We are using the original video to superimpose to the grab
    % We go through every frame of the original video
    frame = videoReader.step();

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
    
    % But the marking may not have been done on every frame
    % So we process only if the frame has been marked
    loc=(i==pawFrames);
    if sum(loc) & ~isempty(pawCentroid(loc))
        %% Create the atari image
        % Reset the image
        atari = uint8(zeros(1080,1920,3));
        % Write the pellet as green
        atari(refCentroid(1,2)-boxSize:refCentroid(1,2)+boxSize,refCentroid(1,1)-boxSize:refCentroid(1,1)+boxSize,:)=pelletBoxColor;
        % Write the paw as red
        atari(pawCentroid(loc,2)-boxSize:pawCentroid(loc,2)+boxSize,pawCentroid(loc,1)-boxSize:pawCentroid(loc,1)+boxSize,:)=pawBoxColor;

        %% Create the video with trace image
        % Reset the image
        vwt = frame;
        % Write the pellet as green
        vwt(refCentroid(1,2)-boxSize:refCentroid(1,2)+boxSize,refCentroid(1,1)-boxSize:refCentroid(1,1)+boxSize,:)=pelletBoxColor;
        % Write the paw as red
        vwt(pawCentroid(loc,2)-boxSize:pawCentroid(loc,2)+boxSize,pawCentroid(loc,1)-boxSize:pawCentroid(loc,1)+boxSize,:)=pawBoxColor;
        % Mark trajectory as yellow
        for j = 1:find(loc)
            vwt(pawCentroid(j,2)-2:pawCentroid(j,2)+2,pawCentroid(j,1)-2:pawCentroid(j,1)+2,:)=traceBoxColor;
        end

        % Mark the paw and pellet in the mask
        % Write the pellet as green
        mask(refCentroid(1,2)-boxSize:refCentroid(1,2)+boxSize,refCentroid(1,1)-boxSize:refCentroid(1,1)+boxSize,:)=pelletBoxColor;
        % Write the paw as red
        mask(pawCentroid(loc,2)-boxSize:pawCentroid(loc,2)+boxSize,pawCentroid(loc,1)-boxSize:pawCentroid(loc,1)+boxSize,:)=pawBoxColor;

        if isempty(grabResult)
            match = [];
        else
            match = pawFrames(loc)==[grabResult(:).frameCount];
        end
        if sum(match)
            % if there is a coinciding grab, then mark the outcome
            outcome = [outcome;{[grabResult(match).outcome,'-',int2str(grabResult(match).frameCount)]}];
            bbox    = [bbox;[grabResult(match).position]];
            grabType{loc} = grabResult(match).outcome;
        else
            grabType{loc} = '';
        end
        if ~isempty(bbox)
            atari   = insertObjectAnnotation(atari, 'rectangle', bbox, outcome);
            mask    = insertObjectAnnotation(mask, 'rectangle', bbox, outcome);
            vwt     = insertObjectAnnotation(vwt, 'rectangle', bbox, outcome);
            % frame   = insertObjectAnnotation(frame, 'rectangle', bbox, outcome);
        end
    end
    if strcmpi(modeFlag,'foreground')
        atariPlayer.step(atari);
        vwtPlayer.step(vwt);
        maskPlayer.step(mask);
        pause(1/frameRate);
    end
    step(atariVideoWriter, atari);
    step(maskVideoWriter, mask);
    step(vwtVideoWriter, vwt);
    
end
release(atariVideoWriter);
release(maskVideoWriter);
release(vwtVideoWriter);
videoFile=traceVideoFile;

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
        offset      = offset(objIdx,:);
        pos         = pos(objIdx,:);
        frameCount  = frameCount(objIdx,:);
        % Add relative centroid of the bbox to the absolute location to calculate absolute position of centroid
        centroid    = pos(:,1:2)+offset(1,1:2); % Hack for now. For some reason offset length is coming one less at times   
        bbox        = pos;
    end
end