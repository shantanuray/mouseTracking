pathstr = uigetdir('.', 'Pick Video Directory');
videolist = dir(fullfile(pathstr, '*.mp4'));
for i = 1:size(videolist, 1)
    disp([num2str(i), '. Analyzing file ', videolist(i).name])
    t = cputime;

    [ignorepath,name,ext] = fileparts(videolist(i).name);
    videoFile = fullfile(videolist(i).folder, videolist(i).name);
    video = VideoReader(videoFile);

    if video.Width < 800
        augName = [name, '_aug', ext];
        augVideoFile=fullfile(videolist(i).folder, augName);
        augVideoWriter = vision.VideoFileWriter(augVideoFile, 'FrameRate', 4, 'FileFormat', 'MPEG4');
        frame_add = zeros(video.Height,800-video.Width,3,1);
        while hasFrame(video)
            frame = readFrame(video);
            new_frame = cat(2, frame, frame_add);
            step(augVideoWriter, new_frame);
        end
        release(augVideoWriter)
        disp([num2str(i), '. Created new video ', augName, ' in ', num2str(cputime-t), 's\n'])
    end
end
   