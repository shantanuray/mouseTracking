function [classifier, hogFeatureSize, cellSize] = svmClassiferTraining(varargin)
% svmClassiferTraining trains a SVM classifier using HOG feature extraction
% based on already classified images of the following classes:
%   - 0 - Pellet
%   - 1 - Retracted paw
%   - 2 - Open paw
% [classifier, hogFeatureSize, cellSize] = svmClassiferTraining(imageFolder);   % Classification has been done previously. Default cell size [4 x 4]
% [classifier, hogFeatureSize, cellSize] = ...
%   svmClassiferTraining(imageFolder, 'cellSize', cellSize, 'standardImageSize', standardImageSize); 
%   - cellSize determines the size of the HOG cell for feature extraction. Smaller the cell, larger the feature size
%       2x2 is generally too small. 8x8 is generally too big. 4x4 is default
%   - cellSize determines the size of the HOG cell for feature extraction. Smaller the cell, larger the feature size
%       2x2 is generally too small. 8x8 is generally too big. 4x4 is default
% Use markClassifierImages before running svmClassiferTraining to mark the different objects
% and save them in appropriately labelled folders (0,1,2)
% See extractHOGFeatures and fitcecoc for more details on the feature extraction and classification


p = inputParser;
defaultCellSize = [4,4];
defaultStandardImageSize = [64,64];

addRequired(p,'imageFolder', @ischar);
addParameter(p,'cellSize',defaultCellSize);
addParameter(p,'standardImageSize',defaultStandardImageSize);

parse(p, varargin{:});

% Read input parameters
imageFolder = p.Results.imageFolder;
cellSize = p.Results.cellSize;
imgStd = logical(zeros(p.Results.standardImageSize));

% Read all images with the their label names from the folder and create a |imageDatastore|
% Please note that the source folder should have the following folders inside (./0,./1,./2,./3)
% 0,1,2,3 represent labels for the SVM Classification
%   - 0 - Pellet images only
%   - 1 - Retracted paw images only
%   - 2 - Open paw images only
%   - 3 - Paw with pellet images only
trainingSet = imageDatastore(imageFolder, 'IncludeSubfolders', true, 'LabelSource', 'foldernames');

% Initialize HOG parameters
% Standardize hogFeatureSize by standardizing size of image for feature extraction

img = readimage(trainingSet, 1);
% The image that was provided for the identified objects may be of different sizes
% To do a correlation in fitcecoc, we need a standard size
% The following step fits the image that has been read into an image of
% standardImageSize
imgStd=img;
% imgStd(1: min(size(img,1),size(imgStd,1)), 1:min(size(img,2),size(imgStd,2))) = ...
%     img(1: min(size(img,1),size(imgStd,1)), 1:min(size(img,2),size(imgStd,2)));
[hog, vis] = extractHOGFeatures(imgStd,'CellSize',cellSize);
hogFeatureSize = length(hog);

% Loop over the trainingSet and extract HOG features from each image
numImages = numel(trainingSet.Files);
trainingFeatures = zeros(numImages, hogFeatureSize, 'single');

for i = 1:numImages
    % Read image
    img = readimage(trainingSet, i);
    % Apply pre-processing steps
    % img = imbinarize(img);
    % Standardize hogFeatureSize by standardizing size of image for feature extraction
    % imgStd(1: min(size(img,1),size(imgStd,1)), 1:min(size(img,2),size(imgStd,2))) = ...
    %     img(1: min(size(img,1),size(imgStd,1)), 1:min(size(img,2),size(imgStd,2)));
    imgStd=img;
    trainingFeatures(i, :) = extractHOGFeatures(imgStd, 'CellSize', cellSize);
end

% Get labels for each image.
trainingLabels = trainingSet.Labels;

% fitcecoc uses SVM learners and a 'One-vs-One' encoding scheme.
classifier = fitcecoc(trainingFeatures, trainingLabels);