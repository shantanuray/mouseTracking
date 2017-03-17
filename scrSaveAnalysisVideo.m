function [r,theta,diffXY,refCentroid,pawCentroid,traceVideoFile] = scrSaveAnalysisVideo(varargin)
% [r,theta,diffXY,refCentroid,pawCentroid,traceVideoFile] = scrSaveAnalysisVideo(actionMatFile, videoFile);
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
% ... = scrSaveAnalysisVideo;
% User will be asked to load a previously saved .mat file and video file
%
% ... = scrSaveAnalysisVideo('MatFile',actionMatFile);
% User will be asked to load a previously saved .mat file. 
%   It assumes video file location is correct in the mat file. If it's not correct,
%   it will request user for video file
%
% ... = scrSaveAnalysisVideo('MatFile',actionMatFile, 'VideoFile',videoFile);
%%%%% See analyzeMouseAction.m and markMouseAction.m for further reference %%%%

% Initialize inputs
modeFlag = 'foreground';

p = inputParser;
defaultVideoFile = '';
defaultMatFile = '';
addParameter(p,'VideoFile',defaultVideoFile, @ischar);
addParameter(p,'MatFile',defaultMatFile, @ischar);
parse(p, varargin{:});

% If mat file is not provided, get from user
if isempty(p.Results.MatFile)
    fileName='';
    while isempty(fileName)
        [fileName, pathName] = uigetfile( ...
               {'*.mat','MAT-files (*.mat)'}, ...
                'Pick the Mouse Paw-Grasp raw data file', ...
                'MultiSelect', 'off');
        load(fullfile(pathName,fileName),'roiData','grabResult','videoFile');
        
    end
else
    load(p.Results.MatFile,'roiData','grabResult','videoFile');
end
if ~isempty(p.Results.VideoFile)
    videoFile = p.Results.VideoFile;
end
% If the videoFile doesn't exist, ask user to provide location
if isempty(dir(videoFile))
    disp(['Warning: Could not find the video file - ' videoFile]);
    disp('Please provide appropriate video file ...')
    [pathName,vidName,vidExt] = fileparts(videoFile);
    [fileName, pathName] = uigetfile( ...
           {[vidName,'*.mp4']}, ...
            ['Pick the Mouse Paw-Grasp video file ', vidName], ...
            'MultiSelect', 'off');
    videoFile = fullfile(pathName, fileName);
end
% Check if appropriate video file has been provided
[pathName,vidName,vidExt] = fileparts(videoFile);
if isempty(vidExt) | ~(strcmpi(vidExt, '.mp4') | strcmpi(vidExt, '.avi')| strcmpi(vidExt, '.mov')| strcmpi(vidExt, '.mts'))
    error('You have not provided appropriate video file. Please locate the original video and try again');
end

[r,theta,diffXY,refCentroid,pawCentroid,traceVideoFile] = analyzeMouseAction(roiData, grabResult, videoFile, modeFlag);