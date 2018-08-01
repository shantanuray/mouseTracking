X = csvread('~/Desktop/Ablated_Pre.csv');
init_reach_x = [find(X(:,3)==1), find(X(:,3)==2)];

reach_plot_h = figure;

for j = 1:size(init_reach_x, 1)
  [f,gof,out] = fit(-X(init_reach_x(j, 1):init_reach_x(j, 2), 1), X(init_reach_x(j, 1):init_reach_x(j, 2), 2), 'smoothingspline');
 
  % plot(f)
  h2 = plot(f, 'b-', -X(init_reach_x(j, 1):init_reach_x(j, 2), 1), X(init_reach_x(j, 1):init_reach_x(j, 2), 2), 'w.');
  legend off
  hold on
end
hold off