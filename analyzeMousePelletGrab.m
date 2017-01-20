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
%                       Structure with fields ('position','imageFile','frameCount')
%   - pawPosition:      Position of the paw in every frame
%                       Structure with fields ('position','imageFile','frameCount')
%   - grabResult:       The outcome of the grab:
%                       * Overreach
%                       * Underreach
%                       * Prehension (user suggested label for prehension)
%                       Structure with fields ('outcome','position','imageFile','frameCount')


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
% Size the mask (paw and pellet)
maskSize = 5;

frameRate = 4;
% Location of saved video
disp('Where should the video be saved?');
savedir=uigetdir(pwd,'Where should the video be saved?');
[~, savePrefix]=fileparts(pelletPosition.imageFile);

% Init video writer
vfile=fullfile(savedir, [savePrefix,'_Trace.mp4']);
videoFWriter = vision.VideoFileWriter(vfile, 'FrameRate', frameRate, 'FileFormat', 'MPEG4');

% Get the furthest tip i.e. bottom left corner of the pellet
pos         = double(cat(1, pelletPosition.position));
refTipXY    = [pos(1,1),pos(1,2)+pos(1,4)];

% Get the furthest tip i.e. bottom left corner of the paw
pos         = double(cat(1, pawPosition.position));
pawTipXY    = [pos(:,1),pos(:,2)+pos(:,4)];


%% Process data
% Get difference between reference (pellet) and paw
diff = pawTipXY-refTipXY;
% Calculate distance
r = sqrt(sum(power(diff,2),2));
theta = atan(diff(:,1)./diff(:,2))*90/pi;
% Plot r and theta
h = figure;
set(h,'Position',[1 1 900 300]);
h1=subplot(1,2,1);
plot([1:length(r)],r,'-r')
ylabel(h1,'Distance from pellet')
xlabel(h1,'Frames')
h2=subplot(1,2,2);
plot([1:length(r)],theta,'-b')
ylabel(h2,'Approach angle (degrees)')
xlabel(h2,'Frames')

videoReader = vision.VideoFileReader(videoFile);
videoPlayer = vision.VideoPlayer('Position', [20, 400, 700, 400]);
maskPlayer = vision.VideoPlayer('Position', [740, 400, 700, 400]);
bbox=[];
outcome={};
%% Save video
% Init the mask
mask = uint8(zeros(1080,1920,3));
for i = 1:pawPosition(end).frameCount
    loc=(i==cat(1,pawPosition.frameCount));
    if sum(loc)
        % Reset the image
        mask = uint8(zeros(1080,1920,3));
        % Write the pellet as green
        mask(refTipXY(1,2)-maskSize:refTipXY(1,2)+maskSize,refTipXY(1,1)-maskSize:refTipXY(1,1)+maskSize,2)=255;
        % Write the paw as red
        mask(pawTipXY(loc,2)-maskSize:pawTipXY(loc,2)+maskSize,pawTipXY(loc,1)-maskSize:pawTipXY(loc,1)+maskSize,1)=255;
        match = pawPosition(loc).frameCount==[grabResult(:).frameCount];
        if sum(match)
            % if there is a coinciding grab, then mark the outcome
            outcome = [outcome;{[grabResult(match).outcome,'-',int2str(grabResult(match).frameCount)]}];
            bbox    = [bbox;[grabResult(match).position]];
        end
        if ~isempty(bbox)
            mask   = insertObjectAnnotation(mask, 'rectangle', bbox, outcome);
        end
    end
    frame = videoReader.step();
    maskPlayer.step(mask);        
    videoPlayer.step(frame);
    pause(1/frameRate);
    step(videoFWriter, frame);
end
release(videoFWriter);
videoFile=vfile;