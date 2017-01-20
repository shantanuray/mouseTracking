function detectorTesting(detector, imgFile)
% detectorTesting(detector, imgFile)
% detector is created in detectorTraining using training images
% imgFile is the test image file

% Read the test image.
img = imread(imgFile);

% Detect the object.
bbox = step(detector,img); 

% Insert bounding box rectangles and return the marked image.
 detectedImg = insertObjectAnnotation(img,'rectangle',bbox,'match');

% Display the detected match
imshow(detectedImg);