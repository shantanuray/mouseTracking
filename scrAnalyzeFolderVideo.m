function data = scrAnalyzeFolderVideo(folderLocation)
% data = scrSaveAnalysisVideo(folderLocation);
% data is a list with the following columns
%   {'videoFile',...
%     'Frame Count',...
%     'Marking',...
%     'Relative Distance',...
%     'Relative Angle of Approach',...
%     'Relative X Distance',...
%     'Relative Y Distance',...
%     'Action',...
%     'ActionType',...
%     'Consequence',...
%     'Pellet X Absolute',...
%     'Pellet Y Absolute',...
%     'Marking X Absolute',...
%     'Marking Y Absolute'
%   };
%
% -------------- Usage --------------
% ... = scrAnalyzeFolderVideo;
% User will be asked to select folder location with a previously saved .mat file and video file
%
% ... = scrAnalyzeFolderVideo(folderLocation);
%%%%% See scrSaveAnalysisVideo.m, analyzeMouseAction.m and markMouseAction.m for further reference %%%%

if nargin<1
    folderLocation = uigetdir('~','Provide folder with mat and video files');
end

dirstruct = dir(folderLocation);

[sorted_names,sorted_index] = sortrows({dirstruct.name}');

%Then eliminate all but the .tif files
filecount = 0;
fileindices = [];
for i=1:length(sorted_names)
    if ~isdir(sorted_names{i})
        [path mname mext] = fileparts(sorted_names{i});
        
        if (strcmpi(mext,'.mat'))
            [path vname vext] = fileparts(sorted_names{i+1});
            if (strcmpi(vext,'.mp4')|strcmpi(vext,'.mov')|strcmpi(vext,'.avi')|strcmpi(vext,'.mts')) & strcmpi(mname,vname))
                filecount = filecount+1;
                fileindices = [fileindices i];
            end
        end
    end
end

if filecount>0
    for i = fileindices
        scrSaveAnalysisVideo('MatFile',fullfile(folderLocation,sorted_names{i}), 'VideoFile',fullfile(folderLocation,sorted_names{i+1}));
    end
end