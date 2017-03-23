function [centroids, clusteridx, theta] = reachClusterAnalysis(data)
    %% reachClusterAnalysis analyzes reaches of control and ablated mice
    %% and attempts to classify them into clusters and prints the 
    %% reaches with respect to the decision boundary
    % 
    % [centroids, clusteridx, theta] = reachClusterAnalysis(data)
    % data          => 3 column matrix of the reaches of control and ablated mice 
    %   (x,y, label) where label = 0 for control and 1 for ablated
    % centroids     => Centroid of the clusters
    % clusteridx    => ID of the cluster for each of the reaches
    % theta         => Decision Boundary

X = data(:, [1, 2]); y = data(:, 3);
figure
plotData(X, y);

% Put some labels 
hold on;

% Labels and Legend
xlabel('X-Coordinate wrt Pellet');
ylabel('Y-Coordinate wrt Pellet');


% k-means cluster analysis
rng(1);
opts = statset('Display','final');
[clusteridx, centroids] = kmeans(X,2,'Distance','cityblock','Replicates',5,'Options',opts);

hold on
plot(centroids(:,1),centroids(:,2),'kx','MarkerSize',15,'LineWidth',3);
legend('Controls', 'Ablated', 'centroids')
hold off

%% Now to draw the decision boundary. Here y = cluster ID
% Add Polynomial Features

% Note that mapFeature also adds a column of ones for us, so the intercept
% term is handled
X = mapFeature(X(:,1), X(:,2));
y = clusteridx;
y(y==1)=0;
y(y==2)=1;

% Initialize fitting parameters
initial_theta = zeros(size(X, 2), 1);

% Set regularization parameter lambda to 1
lambda = 1;

% Compute and display initial cost and gradient for regularized logistic
% regression
[cost, grad] = costFunctionReg(initial_theta, X, y, lambda);

fprintf('Cost at initial theta (zeros): %f\n', cost);

% Initialize fitting parameters
initial_theta = zeros(size(X, 2), 1);


% Set Options
options = optimset('GradObj', 'on', 'MaxIter', 400);


lambda_range = [0, 0.5, 1, 5, 10];
num = length(lambda_range);
for i=1:num
    lambda = lambda_range(i);
    % Optimize
    [theta, J, exit_flag] = fminunc(@(t)(costFunctionReg(t, X, y, lambda)), initial_theta, options);
        
    % Plot Boundary
%     subplot(num, 2, 1 + (i-1)*2)
    figure
    plotDecisionBoundary(theta, X, y);
%     hold on
    title(sprintf('Decision boundary for lambda = %g', lambda))

    % Labels and Legend

    legend('Cluster 2', 'Cluster 1', 'Decision boundary')
%     hold off
    % Compare estimated to actual
%     subplot(num, 2, 2 + (i-1)*2)
    figure
    plot(sigmoid(X*theta),y,'ro')
%     hold on
    title(sprintf('Estimated v/s Actual for lambda = %g', lambda))

    % Labels and Legend
    xlabel('Estimated value')
    ylabel('Actual value')
%     hold off

    % Compute accuracy on our training set
    p = predict(theta, X);

    fprintf('Train Accuracy: %f for lamdba = %d\n', mean(double(p == y)) * 100, lambda);

end



    function plotData(X, y)
        %% PLOTDATA Plots the data points X and y into a new figure 
        %   PLOTDATA(x,y) plots the data points with + for the y == 1 examples
        %   and o for the y == 0 examples. X is assumed to be a Mx2 matrix.

        % Create New Figure

        % ====================== YOUR CODE HERE ======================
        % Instructions: Plot the binary values of y on a 2D plot, using the 
        %       option 'k+' to denote (x1, x2) corresponding to y == 1, and
        %       option 'ko' to denote (x1, x2) corresponding to y == 0.
        %
        plot_colors = ['b';'r'];
        hold_state = ishold;
        legend_str = {'Control','Ablated'};
        y_range = unique(y);
        legend_str = cell(length(y_range),1);
        for i=1:2
            y_sep = find(y==y_range(i));
            plot(X(y_sep,1), X(y_sep,2), [plot_colors(i) '.'],'MarkerSize',20);
            hold on
            legend_str{i} = ['y = ', legend_str{i}];
        end
        % Specified in plot order
        legend(legend_str)
        if (~hold_state) 
            hold off; 
        end

        % =========================================================================
    end

    function plotDecisionBoundary(theta, X, y)
        %% PLOTDECISIONBOUNDARY Plots the data points X and y into a new figure with
        %% the decision boundary defined by theta
        %   PLOTDECISIONBOUNDARY(theta, X,y) plots the data points with + for the 
        %   positive examples and o for the negative examples. X is assumed to be 
        %   a either 
        %   1) Mx3 matrix, where the first column is an all-ones column for the 
        %      intercept.
        %   2) MxN, N>3 matrix, where the first column is all-ones

        hold_state = ishold;
        % Plot Data
        plotData(X(:,2:3), y);
        hold on

        if size(X, 2) <= 3
            % Only need 2 points to define a line, so choose two endpoints
            plot_x = [min(X(:,2))-2,  max(X(:,2))+2];

            % Calculate the decision boundary line
            plot_y = (-1./theta(3)).*(theta(2).*plot_x + theta(1));

            % Plot, and adjust axes for better viewing
            plot(plot_x, plot_y)
            
            % Legend, specific for the exercise
            legend('Admitted', 'Not admitted', 'Decision Boundary')
            axis([30, 100, 30, 100])
        else
            % Here is the grid range
            u = linspace(-1, 1.5, 50);
            v = linspace(-1, 1.5, 50);

            z = zeros(length(u), length(v));
            % Evaluate z = theta*x over the grid
            for i = 1:length(u)
                for j = 1:length(v)
                    z(i,j) = mapFeature(u(i), v(j))*theta;
                end
            end
            z = z'; % important to transpose z before calling contour

            % Plot z = 0
            % Notice you need to specify the range [0, 0]
            contour(u, v, z, [0, 0], 'LineWidth', 2)
        end
        if (~hold_state) 
            hold off; 
        end

    end

    function p = predict(theta, X)
        %PREDICT Predict whether the label is 0 or 1 using learned logistic 
        %regression parameters theta
        %   p = PREDICT(theta, X) computes the predictions for X using a 
        %   threshold at 0.5 (i.e., if sigmoid(theta'*x) >= 0.5, predict 1)

        m = size(X, 1); % Number of training examples

        % You need to return the following variables correctly
        p = zeros(m, 1);

        % ====================== YOUR CODE HERE ======================
        % Instructions: Complete the following code to make predictions using
        %               your learned logistic regression parameters. 
        %               You should set p to a vector of 0's and 1's
        %

        p = sigmoid(X*theta)>=0.5;

        % =========================================================================


    end

    function g = sigmoid(z)
        %SIGMOID Compute sigmoid functoon
        %   J = SIGMOID(z) computes the sigmoid of z.

        % You need to return the following variables correctly 
        g = zeros(size(z));

        % ====================== YOUR CODE HERE ======================
        % Instructions: Compute the sigmoid of each value of z (z can be a matrix,
        %               vector or scalar).

        g = 1./(1+exp(-z));



        % =============================================================

    end

    function [J, grad] = costFunctionReg(theta, X, y, lambda)
        %COSTFUNCTIONREG Compute cost and gradient for logistic regression with regularization
        %   J = COSTFUNCTIONREG(theta, X, y, lambda) computes the cost of using
        %   theta as the parameter for regularized logistic regression and the
        %   gradient of the cost w.r.t. to the parameters. 

        % Initialize some useful values
        m = length(y); % number of training examples

        % You need to return the following variables correctly 
        J = 0;
        grad = zeros(size(theta));

        % ====================== YOUR CODE HERE ======================
        % Instructions: Compute the cost of a particular choice of theta.
        %               You should set J to the cost.
        %               Compute the partial derivatives and set grad to the partial
        %               derivatives of the cost w.r.t. each parameter in theta

        [J_unreg, grad_unreg] = costFunction(theta, X, y);
        % Cost function with regularization
        J = J_unreg + (lambda/(2*m))*(theta(2:end)'*theta(2:end));
        % Gradient function with regularization
        grad = grad_unreg + (lambda/m) * [0;ones(length(theta)-1,1)] .* theta;



        % =============================================================

    end

    function [J, grad] = costFunction(theta, X, y)
        %% COSTFUNCTION Compute cost and gradient for logistic regression
        %   J = COSTFUNCTION(theta, X, y) computes the cost of using theta as the
        %   parameter for logistic regression and the gradient of the cost
        %   w.r.t. to the parameters.

        % Initialize some useful values
        m = length(y); % number of training examples

        % You need to return the following variables correctly 
        J = 0;
        grad = zeros(size(theta));

        % ====================== YOUR CODE HERE ======================
        % Instructions: Compute the cost of a particular choice of theta.
        %               You should set J to the cost.
        %               Compute the partial derivatives and set grad to the partial
        %               derivatives of the cost w.r.t. each parameter in theta
        %
        % Note: grad should have the same dimensions as theta
        %

        h = sigmoid(X*theta);                   % Store the hypothesis function
        diff = h - y;                           % Store the difference between h(x) and y
        J = (-1/m)*(y'*log(h) + (1-y)'*log(1-h)); % Cost function
        for j=1:length(theta)
            grad(j,1) = sum(diff.*X(:,j))/m;
        end






        % =============================================================

    end

    function out = mapFeature(X1, X2, degree)
        % MAPFEATURE Feature mapping function to polynomial features
        %
        %   MAPFEATURE(X1, X2) maps the two input features
        %   to quadratic features used in the regularization exercise.
        %
        %   Returns a new feature array with more features, comprising of 
        %   X1, X2, X1.^2, X2.^2, X1*X2, X1*X2.^2, etc..
        %
        %   Inputs X1, X2 must be the same size
        %

        if (nargin<3)
            degree = 6;
        end
        out = ones(size(X1(:,1)));
        for i = 1:degree
            for j = 0:i
                out(:, end+1) = (X1.^(i-j)).*(X2.^j);
            end
        end

    end
end