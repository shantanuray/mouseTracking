function [centroids, clusteridx] = reachClusterAnalysis(data)
    %% reachClusterAnalysis analyzes reaches of control and ablated mice
    %% and attempts to classify them into clusters and prints the 
    %% reaches with respect to the decision boundary
    % 
    % [centroids, clusteridx] = reachClusterAnalysis(data)
    % data          => 3 column matrix of the reaches of control and ablated mice 
    %   (x,y, label) where label = 0 for control and 1 for ablated
    % centroids     => Centroid of the clusters
    % clusteridx    => ID of the cluster for each of the reaches

X = data(:, [1, 2]); y = data(:, 3);
figure
plotData(X, y);

% k-means cluster analysis
rng(1);
opts = statset('Display','final');
[clusteridx, centroids] = kmeans(X,2,'Distance','cityblock','Replicates',5,'Options',opts);

hold on
plot(centroids(:,1),centroids(:,2),'kx','MarkerSize',15,'LineWidth',3);

plotDecisionBoundary(X, clusteridx);
legend({'Control', 'Ablated', 'Centroid','Separator'},'FontName','Calibri','FontSize',12,'Location','northwest')
ylim([0,1])
xlim([-1,1])
hold off


    function plotData(X, y)
        %% PLOTDATA Plots the data points X and y into a new figure 
        %   PLOTDATA(x,y) plots the data points with + for the y == 1 examples
        %   and o for the y == 0 examples. X is assumed to be a Mx2 matrix.

        plot_colors = ['b';'r'];
        hold_state = ishold;
        y_range = unique(y);
        for i=1:2
            y_sep = find(y==y_range(i));
            plot(X(y_sep,1), X(y_sep,2), [plot_colors(i) '.'],'MarkerSize',20);
            hold on;
        end
        % Specified in plot order
        legend('Ablated','Control')
        if ~hold_state
            hold off; 
        end
    end

    function plotDecisionBoundary(X, clusteridx)
        %% plotDecisionBoundary Plots the decision boundary defined by the
        %% data points X and clusters provided by y 
        % 
        % SVM is trained based on the cluster index and a single contour is drawn
        rng(1);
        SVMModel = fitcsvm(X,clusteridx,'KernelScale','auto','Standardize',true,'OutlierFraction',0.05);
        svInd = SVMModel.IsSupportVector;
        h = 0.02; % Mesh grid step size
        [X1,X2] = meshgrid(min(X(:,1)):h:max(X(:,1)),...
            min(X(:,2)):h:max(X(:,2)));
        [~,score] = predict(SVMModel,[X1(:),X2(:)]);
        scoreGrid = reshape(score(:,1),size(X1,1),size(X2,2));
        v = [1,1];
        contour(X1,X2,scoreGrid,v,'--ks');
     end
end