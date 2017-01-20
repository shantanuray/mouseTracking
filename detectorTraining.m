function [detector, positiveInstances, negativeFolder, positiveFolder]  = detectorTraining(detectorFile, varargin)
% detectorTraining asks user to mark paw in training imageStorage
% It uses the positive and negative matches to training a HOG detector
% User can provide tuning parameter to trainCascadeObjectDetector
% See trainCascadeObjectDetector for more details
% detector = detectorTraining(detectorFile); % Default - no identification has been done previously
% detector = detectorTraining(detectorFile, 'positiveFolder', positiveFolder, ...
%    'negativeFolder', negativeFolder); % Identification of matches has been done but not location
% detector = detectorTraining(detectorFile, 'positiveInstances', positiveInstances, ...
%    'negativeFolder', negativeFolder); % Identification of matches has been done
%                                       % Location has been identified and saved as 
%                                       % positiveInstances = table(fileName, position)


p = inputParser;
defaultPositiveFolder = '';
defaultNegativeFolder = '';
fileName = {};
position = [];
defaultPositiveInstances = table(fileName, position);

addRequired(p,'detectorFile', @ischar);
addParameter(p,'positiveFolder',defaultPositiveFolder, @ischar);
addParameter(p,'negativeFolder',defaultNegativeFolder, @ischar);
addParameter(p,'positiveInstances', defaultPositiveInstances, @istable);

parse(p,detectorFile,varargin{:});

if isempty(p.Results.negativeFolder)
    % Get folder where the training images are stored
    fpath = uigetdir(pwd, 'Choose folder where training paw images have been stored');
    % Prepare folders for storing positive and negative matches
    positiveFolder = fullfile(fpath,'positiveInstances');
    mkdir(positiveFolder);
    negativeFolder = fullfile(fpath,'negativeInstances');
    mkdir(negativeFolder);

    % Create imageDatastore from the raw images
    rawImageSet = imageDatastore(fpath, 'IncludeSubfolders', false);
    numRawImages = numel(rawImageSet.Files);

    % Loop through the images and ask user to identify if there is a match
    % Move images with a match to positiveFolder
    % Move images with no match to negativeFolder
    filecount = 0;
    h1=figure;
    for i=1:numRawImages
        img = readimage(rawImageSet, i);
        fname = rawImageSet.Files{i};
        imshow(img);
        reply = input('Does the image have a paw? Y/N [Enter - N/ Any key - Y]:','s');
        if isempty(reply) | reply == 'N' | reply == 'n'
            copyfile(fname,negativeFolder);
        else
            filecount = filecount+1;
            copyfile(fname,positiveFolder);
            fileName{filecount, 1} = fname;
            position(filecount,:) = getrect;
        end
        contFlag = input('Keep going Y/N [Enter - Y/ N]','s');
        if strcmpi(contFlag, 'n')
            close(h1);
            break;
        end
    end

    positiveInstances = table(fileName, position);
else
    negativeFolder = p.Results.negativeFolder;
    if ~isempty(p.Results.positiveInstances)
        positiveInstances = p.Results.positiveInstances;
    else
        positiveFolder = p.Results.positiveFolder;
        positiveImageSet = imageDatastore(positiveFolder, 'IncludeSubfolders', false);
        numRawImages = numel(positiveImageSet.Files);
        filecount = 0;
        reply = input(['%%%%%%% Starting with object identification %%%%%%%\n',... 
            'Mark a rectangle around the object in the subsequent images. Proceed? [Enter]'],'s');
        h1=figure;
        for i=1:numRawImages
            img = readimage(positiveImageSet, i);
            fname = positiveImageSet.Files{i};
            filecount = filecount+1;
            imshow(img);
            fileName{filecount, 1} = fname;
            position(filecount,:) = getrect;
        end
        close(h1);
        positiveInstances = table(fileName, position);
    end
end

% Train a cascade object detector called using HOG features.
trainCascadeObjectDetector(detectorFile, positiveInstances, negativeFolder, ...
        'FeatureType', 'HOG', ...
        'FalseAlarmRate',0.01,  'TruePositiveRate', 0.999, ...
        'NumCascadeStages',5);

% Use the newly trained classifier to detect a paw in an image.
detector = vision.CascadeObjectDetector(detectorFile);