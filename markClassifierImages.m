function imageFolder = markClassifierImages(varargin)
% imageFolder = markClassifierImages;
% Mark objects to be classified in  video or image files (tiff)
% Program will go through each frame/image and ask user to mark 
% objects to be classified as follows
%   - 0 - Pellet
%   - 1 - Retracted paw
%   - 2 - Open paw
% The marked images will be saved in folder ./matches/[0,1,2]
% Usage:
% imageFolder = markClassifierImages; 
%   User will be asked to point the video file
% imageFolder = markClassifierImages('VideoFile', videoFile);
%   Provide video file. standardImageSize assumed to be [100 x 100 pixels]
% imageFolder = markClassifierImages('VideoFile', videoFile, 'StandardImageSize', standardImageSize);
%   Provide video file and provide standardImageSize
% imageFolder = markClassifierImages('RawImageFolder', fpath);
%   Provide path where the image files are stored (tiff)

p = inputParser;
defaultRawImageFolder = '';
defaultVideoFile = '';
defaultStandardImageSize = [64,64];

addParameter(p,'RawImageFolder',defaultRawImageFolder, @ischar);
addParameter(p,'VideoFile',defaultVideoFile, @ischar);
addParameter(p,'StandardImageSize',defaultStandardImageSize, @isinteger);

parse(p, varargin{:});

% Get folder where the training images are stored
if nargin == 0
    [fileName, fpath] = uigetfile({'*.mp4;*.avi', 'Select video SVM Classification (*.mp4, *.avi)'});
    videoFile = fullfile(fpath, fileName);
    [~, saveFileName] = fileparts(fileName);
elseif ~isempty(p.Results.VideoFile)
    videoFile = p.Results.VideoFile;
    [fpath, saveFileName] = fileparts(videoFile);
elseif ~isempty(p.Results.RawImageFolder)
    rawImageFolder = p.Results.RawImageFolder;
    fpath = rawImageFolder;
    saveFileName = '';
else
    error('Incorrect input provided. See help markClassifierImages.');
end

standardImageSize = int16(p.Results.StandardImageSize);

%% Initialize
% Prepare folders for storing matches
%   - 0 - Pellet
%   - 1 - Retracted paw
%   - 2 - Open paw
%   - 3 - Paw with pellet
imageFolder = fullfile(fpath,'matches');
mkdir(imageFolder);
for i = 0:2
    folder{i+1,1} = fullfile(imageFolder,num2str(i));
    mkdir(folder{i+1,1});
end

matchCount(1:3) = 0;
contFlag = 'Y';
imgMatch = zeros(standardImageSize);

%% Start processing
h1=figure;

if ~isempty(videoFile)
    % Read video file
    vidObj = VideoReader(videoFile);
    while hasFrame(vidObj) & ~strcmpi(contFlag,'n')
        % Read frame
        frame = readFrame(vidObj);
        % Call imageMarkSave for the given frame/image to mark object for classification
        matchCount = imageMarkSave(frame, matchCount);
        contFlag = input('Do you wish to keep going? [Enter - Y | N]: ', 's');
    end
else
    % Create imageDatastore from the raw images
    rawImageSet = imageDatastore(fpath, 'IncludeSubfolders', false,'LabelSource', 'foldernames');
    numRawImages = numel(rawImageSet.Files);
    for i = 1:numRawImages
        % Read frame
        img = readimage(rawImageSet, i);
        % Call imageMarkSave for the given frame/image to mark object for classification
        matchCount = imageMarkSave(img, matchCount);
        contFlag = input('Do you wish to keep going? [Enter - Y | N]: ', 's');
        if strcmpi(contFlag,'n')
            break;
        end
    end
end
close(h1); return;

    %% For the given frame/image, ask the user to identify
    % and mark objects
    % Return count of matched objects
    function matchCount = imageMarkSave(img, matchCount)
        
        % Take selected image part and write as JPEG to 
        % to appropriate folder depending on label (below):
        %   - 0 - Pellet
        %   - 1 - Retracted paw
        %   - 2 - Open paw
        %   - 3 - Paw with pellet
        optionStr = ['What do you wish to mark in the image? \n', ...
            '0 - Pellet\n', ...
            '1 - Paw closed\n', ...
            '2 - Paw open\n', ...
            '[Any other key] - Done with this image\n'];

        options = {'0','1','2'};
        
        % Show image
        imshow(img);
        
        % Ask user if any object needs to be marked and if so, which one
        reply = input(optionStr,'s');
        while sum(strcmp(reply, options))
            optNum = str2num(reply);
            % Mark the object
            position = int16(getrect);
            % Get marked image (size as marked)
            imgMarked = getImageMarked(img, position);
            
            %% Now we will select a region of standard image size (def 100 x 100) around
            % the centroid of the marked region and save this
            
            %% Binarize the marked image
            imgBin = imbinarize(rgb2gray(imgMarked));

            %% Extract the centroid (if marked properly, there should be only one centroid,
            % i.e. [x y] coordinates of the centroid of the marked image
            % regionprops returns a structure as imageProp.Centroid relative to the marked image
            imageProp = regionprops(imgBin,'centroid'); 
            centroids = int16(cat(1, imageProp.Centroid)); % Convert the structure to an array of int
            % If more than one centroid is detected, choose the centroid that is closest to the 
            % center of the select image [size(imgBin)/2]
            centroids = centroids(abs([size(imgBin,1)/2-centroids(:,1), size(imgBin,2)/2-centroids(:,2)])==...
              min(abs([size(imgBin,1)/2-centroids(:,1), size(imgBin,2)/2-centroids(:,2)]),[],1));
            % When there is a single centroid, above function returns a row vector as required
            % When there multiple centroids, even though the above returns the correct centroid location,
            %   it returns it as a column vector. Convert by default to row vector as required
            % TODO Check why sometimes length(centroids)~=2. For now, continue
            if length(centroids)~=2
                disp(imageProp);
                disp(size(imgBin,1));
                continue;
            end
            centroidRow=reshape(centroids,[1 2]); 

            %% Calculated position of region wrt original image
            % 1. Calculate location of centroid wrt original image
            %   centroids = centroids + position(1:2);          
            % 2. Then mark the top left corner of 100 x 100 region around centroid
            %   position(1:2) = [centroids(1)-50, centroids(2)-50];
            % 3. Then finally mark the width and height of the 100 x 100 region
            %   position(3:4) = [100 100];
            position = [[centroidRow + position(1:2) - int16(standardImageSize/2)],standardImageSize];
            % Get marked image (standard image size around marked image centroid)
            imgMatch = getImageMarked(img, position);
            matchCount(optNum+1) = matchCount(optNum+1) + 1;
            
            %% Write image
            imwrite(imgMatch, fullfile(folder{optNum+1,1}, [saveFileName, reply,'_', num2str(matchCount(optNum+1)),'.jpg']), 'JPEG');
            
            % Ask user again if any object needs to be marked and if so, which one
            reply = input(optionStr,'s');
        end
    end

    %% For the given box, [x y width height], return the selected image with actual
    % coordinates [row(1):row(end), column(1):column(end)]
    function imgMarked = getImageMarked(img, position)
        imgMarked = img(position(2):position(2)+position(4)-1, position(1):position(1)+position(3)-1,:);
    end

end