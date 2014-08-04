%%


clear all

% Create a really easy model to learn
rand('state', 1);
O = 2;
S = 2;
A = 2;
prior0 = [1 0]';
transmat0 = cell(1,A);
transmat0{1} = [0.9 0.1; 0.1 0.9]; % long runs of 1s and 2s
transmat0{2} = [0.1 0.9; 0.9 0.1]; % short runs
obsmat0 = eye(2);
	   
%prior0 = normalise(rand(S,1));
%transmat0 = mk_stochastic(rand(S,S));
%obsmat0 = mk_stochastic(rand(S,O));

T = 20;
act = [1*ones(1,5) 2*ones(1,5) 1*ones(1,5) 2*ones(1,5)];
data = pomdp_sample(prior0, transmat0, obsmat0, act)
%data = sample_dhmm(prior0, transmat0, obsmat0{1}, T, 1)
%data = [1,1,1,1,1,1,1,1,2,2,2,2,1,1,1,1,2,1,1,1];
init_q = [0.5 0.5];
res_q = zeros(1,20);
% Initial guess of params
rand('state', 2); % different seed!
transmat1 = cell(1,A);
for a=1:A
  transmat1{a} = mk_stochastic(rand(S,S));
end
%obsmat1 = mk_stochastic(rand(S,O));
obsmat1 = [0.95 , 0;0,0.55];
prior1 = prior0; % so it labels states the same way

% Uniformative Dirichlet prior (expected sufficient statistics / pseudo counts)
e = 0.001;
ess_trans = cell(1,A);
for a=1:A
  ess_trans{a} = repmat(e, S, S);
end
ess_emit = repmat(e, S, O);

% Params
w = 2;
decay_sched = [0.1:0.1:0.9];

% Initialize
LL1 = zeros(1,T);
t = 1;
y = data(t);
data_win = y;
act_win = [1]; % arbitrary initial value
[prior1, LL1(1)] = normalise(prior1 .* obsmat1(:,y));
%%
% Likelihood for bayesian occupancy grid mapping. 

TrueHit = 0.98;
FalseAlarm = 0.8;
b_init_q = 0.5;
b_prob = 0.5*ones(1,T);

%%
% Iterate
for t=2:T
  y = data(t);
  a = act(t);
  if t <= w
    data_win = [data_win y];
    act_win = [act_win a];
  else
    data_win = [data_win(2:end) y];
    act_win = [act_win(2:end) a];
    prior1 = gamma(:, 2);
  end
  d = decay_sched(min(t, length(decay_sched)));
  [transmat1, obsmat1, ess_trans, ess_emit, gamma, ll] = dhmm_em_online(...
      prior1, transmat1, obsmat1, ess_trans, ess_emit, d, data_win, act_win);
  bel = gamma(:, end);
  LL1(t) = ll/length(data_win);
  fprintf('t=%d, ll=%f\n', t, ll);
  
  q_update = occupancyUpdate(init_q,transmat1,obsmat1)
  init_q = q_update;
  res_q(t)= q_update(2);
%   if(data(t)==2)
%       Bel_Occ = TrueHit*b_init_q
%       Bel_Unocc = FalseAlarm*(1-b_init_q);
%       b_init_q = Bel_Occ/(Bel_Occ + Bel_Unocc);
%   else
%       Bel_Occ = (1-TrueHit)*b_init_q
%       Bel_Unocc = (1-FalseAlarm)*(1-b_init_q);
%       b_init_q = Bel_Occ/(Bel_Occ + Bel_Unocc);
%    end;
%    b_prob(t)=b_init_q;
end

LL1(1) = LL1(2); % since initial likelihood is for 1 slice
plot(1:T, LL1, 'rx-');
figure(2);
plot(1:T,res_q,'rx-');
figure(3);
scatter(1:T,data);
% figure(4);
% plot(1:T,b_prob,'rx-');

%%
% 
% % compare with offline learning
% 
% if 0
% rand('state', 2); % same seed as online learner
% transmat2 = cell(1,A);
% for a=1:A
%   transmat2{a} = mk_stochastic(rand(S,S));
% end
% obsmat2 = mk_stochastic(rand(S,O));
% prior2 = prior0;
% [LL2, prior2, transmat2, obsmat2] = dhmm_em(data, prior2, transmat2, obsmat2, ....
% 					       'max_iter', 10, 'thresh', 1e-3, 'verbose', 1, 'act', act);
% 
% LL2 = LL2 / T;
% 
% end

