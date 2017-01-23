function [r,theta,diffXY,grabType,refCentroid,pawCentroid,traceVideoFile] = analyzeMousePelletGrab(pelletPosition, pawPosition, grabResult, videoFile, modeFlag)
% [r,theta,diffXY,outcome,refCentroid,pawCentroid,traceVideoFile] = analyzeMousePelletGrab(pelletPosition, pawPosition, grabResult, videoFile, modeFlag);
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
% [r,theta,diffXY,outcome] = analyzeMousePelletGrab(pelletPosition, pawPosition, grabResult, videoFile, modeFlag);
%
% -------------- Inputs --------------
% Provide necessary inputs. Please maintain structure as follows
%   - pelletPosition:   Position of the target pellet identified 
%                       at the start of the program
%                       Structure with fields ('position','centroid',imageFile','frameCount')
%   - pawPosition:      Position of the paw in every frame
%                       Structure with fields ('position','centroid','imageFile','frameCount')
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
                'Pick the Marked Mouse Pellet Grab file', ...
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

% Init video writers
traceVideoFile{1}=fullfile(savedir, [savePrefix,'_Trace.mp4']);
atariVideoWriter    = vision.VideoFileWriter(traceVideoFile{1}, 'FrameRate', frameRate, 'FileFormat', 'MPEG4');
traceVideoFile{2}=fullfile(savedir, [savePrefix,'_VideoWTrace.mp4']);
vwtVideoWriter     = vision.VideoFileWriter(traceVideoFile{2}, 'FrameRate', frameRate, 'FileFormat', 'MPEG4');
% traceVideoFile{3}=fullfile(savedir, [savePrefix,'_Mask.mp4']);
% maskVideoWriter     = vision.VideoFileWriter(traceVideoFile{3}, 'FrameRate', frameRate, 'FileFormat', 'MPEG4');

if strcmpi(modeFlag,'foreground')
    %% Init the video players
    % Atari Video - Square boxes to denote objects
    atariPlayer = vision.VideoPlayer('Position', [20, 400, 700, 400]);

    % Actual Video with Trace
    vwtPlayer = vision.VideoPlayer('Position', [740, 400, 700, 400]);

    % Mask Video - Actual marked objects shown as black and white
    % maskPlayer = vision.VideoPlayer('Position', [740, 400, 700, 400]);
end


%% Start processing
% Get the centroid and bbox of the pellet
[refCentroid, refBox] = getBox(pelletPosition);

% Get the centroid and bbox of the paw
[pawCentroid, pawBox] = getBox(pawPosition);

% Original axes had top-left corner as (0,0)
% Change axes so that pellet is reference is at the bottom
% Get diffXYerence between reference (pellet) and paw
diffXY = pawCentroid-refCentroid;
% Adjust y-axis so that pellet reference is bottom
diffXY(:,2)=-diffXY(:,2);

% Calculate distance
r = sqrt(sum(power(diffXY,2),2));
theta = atan(diffXY(:,1)./diffXY(:,2))*90/pi;

if strcmpi(modeFlag,'foreground')
    h = plotPawTrajectory(diffXY, r, theta)
end

%% Save video
% Init the mask and the atari base images
% mask   = uint8(zeros(1080,1920,3));
atari   = uint8(zeros(1080,1920,3));
vwt     = uint8(zeros(1080,1920,3));
bbox    = [];
outcome = {};
grabType= {};
for i = 1:pawPosition(end).frameCount
    % We are using the original video to superimpose to the grab
    % We go through every frame of the original video
    frame = videoReader.step();
    
    % But the marking may not have been done on every frame
    % So we process only if the frame has been marked
    loc=(i==cat(1,pawPosition.frameCount));
    if sum(loc) & ~isempty(pawPosition(loc).centroid)
        disp(i)
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

        % %% Create the mask image
        % % Reset the image
        % mask = uint8(zeros(1080,1920,3));
        % % Write a white pellet image to a black background
        % img = imbinarize(rgb2gray(getImageMarked(frame,refBox)));
        % % mask(refBox(2):refBox(2)+refBox(4)-1,refBox(1):refBox(1)+refBox(3)-1,1) = 255*(img==1);
        % % mask(refBox(2):refBox(2)+refBox(4)-1,refBox(1):refBox(1)+refBox(3)-1,2) = 255*(img==1);
        % % mask(refBox(2):refBox(2)+refBox(4)-1,refBox(1):refBox(1)+refBox(3)-1,3) = 255*(img==1);
        % mask(refCentroid(1,2)-boxSize:refCentroid(1,2)+boxSize,refCentroid(1,1)-boxSize:refCentroid(1,1)+boxSize,1)=0;
        % mask(refCentroid(1,2)-boxSize:refCentroid(1,2)+boxSize,refCentroid(1,1)-boxSize:refCentroid(1,1)+boxSize,2)=255;
        % mask(refCentroid(1,2)-boxSize:refCentroid(1,2)+boxSize,refCentroid(1,1)-boxSize:refCentroid(1,1)+boxSize,3)=0;
        % % Write the white paw image to the mask
        % img = imbinarize(rgb2gray(getImageMarked(frame,pawBox(loc,:))));
        % mask(pawBox(loc,2):pawBox(loc,2)+pawBox(loc,4)-1,pawBox(loc,1):pawBox(loc,1)+pawBox(loc,3)-1,1)=255*(img==1);
        % mask(pawBox(loc,2):pawBox(loc,2)+pawBox(loc,4)-1,pawBox(loc,1):pawBox(loc,1)+pawBox(loc,3)-1,2)=255*(img==1);
        % mask(pawBox(loc,2):pawBox(loc,2)+pawBox(loc,4)-1,pawBox(loc,1):pawBox(loc,1)+pawBox(loc,3)-1,3)=255*(img==1);
        % mask(pawCentroid(loc,2)-boxSize:pawCentroid(loc,2)+boxSize,pawCentroid(loc,1)-boxSize:pawCentroid(loc,1)+boxSize,1)=255;
        % mask(pawCentroid(loc,2)-boxSize:pawCentroid(loc,2)+boxSize,pawCentroid(loc,1)-boxSize:pawCentroid(loc,1)+boxSize,2)=0;
        % mask(pawCentroid(loc,2)-boxSize:pawCentroid(loc,2)+boxSize,pawCentroid(loc,1)-boxSize:pawCentroid(loc,1)+boxSize,3)=0;

        match = pawPosition(loc).frameCount==[grabResult(:).frameCount];
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
            % mask   = insertObjectAnnotation(mask, 'rectangle', bbox, outcome);
            vwt   = insertObjectAnnotation(vwt, 'rectangle', bbox, outcome);
            % frame   = insertObjectAnnotation(frame, 'rectangle', bbox, outcome);
        end
        if strcmpi(modeFlag,'foreground')
            atariPlayer.step(atari);
            % maskPlayer.step(mask);
            vwtPlayer.step(vwt);
            pause(1/frameRate);
        end
        step(atariVideoWriter, atari);
        % step(maskVideoWriter, mask);
        step(vwtVideoWriter, vwt);
    end
end
release(atariVideoWriter);
% release(maskVideoWriter);
release(vwtVideoWriter);
videoFile=traceVideoFile;

    %% For the given box, [x y width height], return the selected image with actual
    % coordinates [row(1):row(end), column(1):column(end)]
    function imgMarked = getImageMarked(img, position)
        imgMarked = img(position(2):position(2)+position(4)-1, position(1):position(1)+position(3)-1,:);
    end

    function [centroid, bbox] = getBox(objPosition)
        offset      = double(cat(1, objPosition.centroid));
        pos         = double(cat(1, objPosition.position));
        centroid    = pos(:,1:2)+offset(1,1:2); % Hack for now. For some reason offset length is coming one less at times
        bbox        = pos;
    end
end