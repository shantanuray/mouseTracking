function imageDir = convertvideo2Image(varargin)
% Converts video to image sequence of required format and returns location of images
% imageDir = convertvideo2Image('Property', 'Value')
% Example:
% imageDir = convertvideo2Image('VideoFile','gait_video.mp4','Format','PNG', 'TargetLocation','~')
%   Reads videoFile gait_video.mp4 and converts to image sequence (gait_video_001, gait_video_002, ..) 
%   and stores in ~/gait_video_images/
%   Returns the '~/gait_video_images/' where the images are stored if successful
% Properties:
% * VideoFile - Input video to be processed
% * Format - Format of image to be saved as
% * TargetLocation - Location where the image sequence should be saved

imageDir = '';

p = inputParser;
defaultVideoFile = '';
defaultFormat = 'PNG';
defaultTargetLocation = '';

addParameter(p,'VideoFile',defaultVideoFile, @ischar);
addParameter(p,'Format',defaultFormat, @ischar);
addParameter(p,'TargetLocation',defaultTargetLocation, @ischar);

%% TODO Provide support for image files
% addParameter(p,'RawImageFolder',defaultRawImageFolder, @ischar);

%% Read inputs
parse(p, varargin{:});
% Format
imgFormat = p.Results.Format;
% Video file
if isempty(p.Results.VideoFile)
    disp('Choose the video file to process');
    [videoFile, pathName] = uigetfile({'*.mp4;*.avi', 'Video Files (*.mp4, *.avi)'});
    videoLoc = fullfile(pathName, videoFile);
    [pathname,fileName,fileExt] = fileparts(videoLoc);
else
    videoLoc = p.Results.VideoFile;
    [pathname,fileName,fileExt] = fileparts(videoLoc);
    videoFile = [fileName,fileExt];
end

% Target directory to save images
if isempty(p.Results.TargetLocation)
    disp('Choose the folder to save the images');
    workingDir = uigetdir(pwd, 'Pick folder to save the images');
else
    workingDir = p.Results.TargetLocation;
end

vidObj = VideoReader(videoLoc);

% Check if there are frames to read
if hasFrame(vidObj)
    imageDir = fullfile(workingDir, [fileName, '_images']);
    if ~isdir(imageDir)
      mkdir(imageDir);
    end
    
    ii = 1;

    while hasFrame(vidObj)
       img = readFrame(vidObj);
       imgFileName = [sprintf('%s_%03d',fileName,ii), '.', lower(imgFormat)];
       imgFullName = fullfile(imageDir, imgFileName);
       imwrite(img,imgFullName, imgFormat);
       ii = ii+1;
    end
end
return