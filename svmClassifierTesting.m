function [predictedLabels, confMat] = svmClassifierTesting(classifier, hogFeatureSize, cellSize, testImageFolder)
% svmClassifierTesting(classifier, hogFeatureSize, cellSize)
% (classifier, hogFeatureSize, cellSize) can be obtained from svmClassifierTraining
% testImageFolder is the location where test files are stored with respective labels
% Use markClassifierImages before running svmClassifierTesting to mark the different objects
% and save them in appropriately labelled folders (0,1,2,3) to provide testImageFolder

% |imageDatastore| recursively scans the directory tree containing the
% images. Folder names are automatically used as labels for each image.
testSet     = imageDatastore(testImageFolder, 'IncludeSubfolders', true, 'LabelSource', 'foldernames');

% Extract HOG features from the test set. 
numImages = numel(testSet.Files);
testFeatures  = zeros(numImages, hogFeatureSize, 'single');

% Process each image and extract features
for j = 1:numImages
    imgStd = uint8(zeros(100,100));
    img = readimage(testSet, j);
    imgStd(1: min(size(img,1),size(imgStd,1)), 1:min(size(img,2),size(imgStd,2))) = ...
        img(1: min(size(img,1),size(imgStd,1)), 1:min(size(img,2),size(imgStd,2)));
    % Apply pre-processing steps
    imgStd = imbinarize(imgStd);
    
    testFeatures(j, :) = extractHOGFeatures(imgStd,'CellSize',cellSize);
end

% Make class predictions using the test features.
predictedLabels = predict(classifier, testFeatures);

% Tabulate the results using a confusion matrix.
confMat = confusionmat(testSet.Labels, predictedLabels);