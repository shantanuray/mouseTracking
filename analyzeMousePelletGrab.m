function [r,theta,videoFile] = analyzeMousePelletGrab(pelletPosition, pawPosition, grabResult)
% [r,theta,videoFile] = analyzeMousePelletGrab(pelletPosition, pawPosition, grabResult);
% Usage:
% [r,theta,videoFile] = analyzeMousePelletGrab;
% User will be asked to load a previously saved .mat file with the necessary inputs
%
% [r,theta,videoFile] = analyzeMousePelletGrab(pelletPosition, pawPosition, grabResult);
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


% Initialize
if nargin~=3
    fileName='';
    while isempty(fileName)
        [fileName, pathName] = uigetfile( ...
               {'*.mat','MAT-files (*.mat)'}, ...
                'Pick the Marked Mouse Pellet Grab file', ...
                'MultiSelect', 'off');
        load(fullfile(pathName,fileName),'pelletPosition','pawPosition','grabResult','videoFile');
    end
end
% Size the atari box size (paw and pellet)
boxSize = 5;

frameRate = 4;
% Location of saved video
disp('Where should the video be saved?');
savedir=uigetdir(pwd,'Where should the video be saved?');
[~, savePrefix]=fileparts(pelletPosition.imageFile);

% Init the video reader
videoReader = vision.VideoFileReader(videoFile);

% Init video writers
vfile{1}=fullfile(savedir, [savePrefix,'_Trace.mp4']);
atariVideoWriter    = vision.VideoFileWriter(vfile{1}, 'FrameRate', frameRate, 'FileFormat', 'MPEG4');
vfile{2}=fullfile(savedir, [savePrefix,'_Mask.mp4']);
% maskVideoWriter     = vision.VideoFileWriter(vfile{2}, 'FrameRate', frameRate, 'FileFormat', 'MPEG4');
vfile{3}=fullfile(savedir, [savePrefix,'_VideoWTrace.mp4']);
vwtVideoWriter     = vision.VideoFileWriter(vfile{3}, 'FrameRate', frameRate, 'FileFormat', 'MPEG4');

%% Init the video players
% Atari Video - Square boxes to denote objects
atariPlayer = vision.VideoPlayer('Position', [20, 400, 700, 400]);

% Actual Video with Trace
vwtPlayer = vision.VideoPlayer('Position', [740, 400, 700, 400]);

% Mask Video - Actual marked objects shown as black and white
% maskPlayer = vision.VideoPlayer('Position', [740, 400, 700, 400]);


%% Start processing
% Get the centroid of the pellet
offset      = double(cat(1, pelletPosition.centroid));
pos         = double(cat(1, pelletPosition.position));
refCentroid = pos(1,1:2)+offset;
refBox      = pos(1,:);

% Get the centroid of the paw
offset      = double(cat(1, pawPosition.centroid));
pos         = double(cat(1, pawPosition.position));
pawCentroid = pos(1:length(offset),1:2)+offset;
pawBox      = pos(1:length(offset),:);

% Get difference between reference (pellet) and paw
diff = pawCentroid-refCentroid;
% Calculate distance
r = sqrt(sum(power(diff,2),2));
theta = atan(diff(:,1)./diff(:,2))*90/pi;
% Plot r and theta
h = figure;
set(h,'Position',[1 1 900 300]);
h1=subplot(1,4,1);
plot([1:length(r)],r,'-r')
ylabel(h1,'Distance from pellet')
xlabel(h1,'Frames')
h2=subplot(1,4,2);
plot([1:length(r)],theta,'-b')
ylabel(h2,'Approach angle (degrees)')
xlabel(h2,'Frames')
h3=subplot(1,4,3);
plot(diff(:,1),abs(diff(:,2)))
ylabel(h3,'Approach - Y')
xlabel(h3,'Approach - X')
h3=subplot(1,4,4);
plot(theta,r)
ylabel(h3,'Approach - Distance')
xlabel(h3,'Approach - Theta')

%% Save video
% Init the mask and the atari base images
% mask   = uint8(zeros(1080,1920,3));
atari   = uint8(zeros(1080,1920,3));
vwt     = uint8(zeros(1080,1920,3));
bbox=[];
outcome={};
for i = 1:pawPosition(end).frameCount
    frame = videoReader.step();
    loc=(i==cat(1,pawPosition.frameCount));
    if sum(loc)
        %% Create the atari image
        % Reset the image
        atari = uint8(zeros(1080,1920,3));
        % Write the pellet as green
        atari(refCentroid(1,2)-boxSize:refCentroid(1,2)+boxSize,refCentroid(1,1)-boxSize:refCentroid(1,1)+boxSize,2)=255;
        % Write the paw as red
        atari(pawCentroid(loc,2)-boxSize:pawCentroid(loc,2)+boxSize,pawCentroid(loc,1)-boxSize:pawCentroid(loc,1)+boxSize,1)=255;

        %% Create the video with trace image
        % Reset the image
        vwt = frame;
        % Write the pellet as green
        vwt(refCentroid(1,2)-boxSize:refCentroid(1,2)+boxSize,refCentroid(1,1)-boxSize:refCentroid(1,1)+boxSize,2)=255;
        % Write the paw as red
        vwt(pawCentroid(loc,2)-boxSize:pawCentroid(loc,2)+boxSize,pawCentroid(loc,1)-boxSize:pawCentroid(loc,1)+boxSize,1)=255;
        % Mark trajectory as blue
        for i = 1:find(loc)
            vwt(pawCentroid(i,2)-2:pawCentroid(i,2)+2,pawCentroid(i,1)-2:pawCentroid(i,1)+2,1)=255;
            vwt(pawCentroid(i,2)-2:pawCentroid(i,2)+2,pawCentroid(i,1)-2:pawCentroid(i,1)+2,2)=255;
            vwt(pawCentroid(i,2)-2:pawCentroid(i,2)+2,pawCentroid(i,1)-2:pawCentroid(i,1)+2,3)=0;
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
        end
        if ~isempty(bbox)
            atari   = insertObjectAnnotation(atari, 'rectangle', bbox, outcome);
            % mask   = insertObjectAnnotation(mask, 'rectangle', bbox, outcome);
            vwt   = insertObjectAnnotation(vwt, 'rectangle', bbox, outcome);
            frame   = insertObjectAnnotation(frame, 'rectangle', bbox, outcome);
        end
    end
    atariPlayer.step(atari);
    % maskPlayer.step(mask);
    vwtPlayer.step(vwt);
    pause(1/frameRate);
    step(atariVideoWriter, atari);
    % step(maskVideoWriter, mask);
    step(vwtVideoWriter, vwt);
end
release(atariVideoWriter);
% release(maskVideoWriter);
release(vwtVideoWriter);
videoFile=vfile;

    %% For the given box, [x y width height], return the selected image with actual
    % coordinates [row(1):row(end), column(1):column(end)]
    function imgMarked = getImageMarked(img, position)
        imgMarked = img(position(2):position(2)+position(4)-1, position(1):position(1)+position(3)-1,:);
    end
end