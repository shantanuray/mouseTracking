function h = plotPawTrajectory(diffXY, r, theta)

% Plot r and theta
h = figure;
set(h,'Position',[1 1 900 300]);
h1=subplot(1,4,1);
plot([1:length(r)],r,'-r')
ylabel(h1,'Distance from pellet')
xlabel(h1,'Frames')
h2=subplot(1,4,2);
plot([1:length(r)],theta,'-b')
ylabel(h2,'Approach angle (degrees)')
xlabel(h2,'Frames')
h3=subplot(1,4,3);
plot(diffXY(:,1),diffXY(:,2))
ylabel(h3,'Approach - Y')
xlabel(h3,'Approach - X')
h3=subplot(1,4,4);
plot(theta,r)
ylabel(h3,'Approach - Distance')
xlabel(h3,'Approach - Theta')