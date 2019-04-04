load('SupplyChain_data.mat'); % Load FactSet Dataset
COMPANY={'259'}; %FactSet ID of the Focal company
% Remove Government supply relation data from dataset
% this step is performed to remove as we focus on supply-relations of
% non-government businesses.
for si=1:length(data(:,1))
    if data(si,3)== 20685
        data(si,:)=0;
    end
    if data(si,4)== 20685
        data(si,:)=0;
    end
end
data_new(:,1)=nonzeros(data(:,1));
data_new(:,2)=nonzeros(data(:,2));
data_new(:,3)=nonzeros(data(:,3));
data_new(:,4)=nonzeros(data(:,4));
data=data_new;
% data has 4 columns
% Column 3. business relation Start date; Column 4. business relation End date
% Column 1. Supplier Company i; Column 2. Buyer Company j;
% Create quarter-wise supply-relations data
first_date = data(1,1); % earliest date in data 
start_n = data(:,1) - first_date +1; % vector of start dates of business relation
end_n = data(:,2) - first_date +1; % vector of end dates of business relation
duration = end_n - start_n + 1; % durations of business relations
Total_time = max(end_n); % Total time of analysis.
data_list_length = length(data(:,1));
%Initialize Matrix for business relations over time
% 1 if i->j business relation exist at time t,
% 0 otherwise
relation_imask = false(data_list_length,Total_time+1); 
for i=1:data_list_length
    for tt=start_n(i):end_n(i)
        relation_imask(i,tt) = 1;
    end
end
Total_quarters=round(Total_time/90)+1; % Total number of Quarters
% Quarter-wise business relation data
% 1 if i->j business relation exist at Quarter Qt,
% 0 otherwise
for t=1:Total_quarters-1
    Quarter_relation_imask(:,t) = sum(relation_imask(:,90*(t-1)+1:90*(t-1)+90),2)>0;
end
Quarter_relation_imask(:,Total_quarters)=sum(relation_imask(:,90*(Total_quarters-1)+1:end),2)>0;
% Start the Quarter-wise analysis of supply network
for t=1:40 % loop to run from quarter 1 to 40 
    % Selecting Company data from Column 3 and 4 that 
    % has Business relation at Quarter Qt 
    network=[data(Quarter_relation_imask(:,t),3),data(Quarter_relation_imask(:,t),4)];
    uniqueA = cellstr(unique(categorical(network), 'rows'));% select only unique elements
    % create directed network graph for company relations
    % Each node in this network represents a company
    % Each link in this network represents a supply relation
    Supply_Network = digraph(uniqueA(:,1), uniqueA(:,2)); 
    % Network node index for focal company
    inode=findnode(Supply_Network,COMPANY);
    % Euclidean distances between nodes in the network
    map = single(distances(Supply_Network));
    map(~isfinite(map))=0;
    %Euclidean distances between focal company and rest of network nodes
    supplier_distance=map(:,inode); 
    % logical indexing to get non-zeros euclidean distances
    % we create a new directed network that contains companies which
    % supply to the focal company
    company_imask=supplier_distance>0;
    company_imask(inode,1)=1;
    % Directed network containing focal company and it's supplier companies
    d_T{t}=rmnode(Supply_Network,table2array(Supply_Network.Nodes(~company_imask,1)));%
    map_next = single(distances(d_T{t}));
    map_next(~isfinite(map_next))=0;
    inode_next=findnode(d_T{t},COMPANY);
    % Euclidean distances between focal company and rest of network nodes
    % This is what we use for defining tier of suppliers
    supplier_distance_next{t}=map_next(:,inode_next);
    % List of Company Nodes
    NodesList{t}=table2cell(d_T{t}.Nodes);
    %HashMap between Node and it's Tier
    TierMap{t}=containers.Map(NodesList{t},supplier_distance_next{t});
end
%% In this section we analyse the network ties into the future. 
% Nodes that are present/not present in next quarter
for t=1:39
    % Nodes present in the next quarter
    FuturePresent{t}=NodesList{t}(ismember(NodesList{t},NodesList{t+1}));
    % Nodes absent in next quarter
    FutureAbsent{t}=NodesList{t}(~ismember(NodesList{t},NodesList{t+1}));    
end
% Change in tier for node that are present in last quarter
for t=1:39
    for i=1:length(FuturePresent{t})
        TierChange{t}(i)=TierMap{t+1}(FuturePresent{t}{i})-TierMap{t}(FuturePresent{t}{i}); 
    end
end
% Nodes based on change in tier status, %1. Stayed at the same tier 
%2. Moved to farther tier, 3. Moved to closer tier
for t=1:39
    Constants{t}=FuturePresent{t}(TierChange{t}==0);
    MovedAway{t}=FuturePresent{t}(TierChange{t}>0);
    MovedCloser{t}=FuturePresent{t}(TierChange{t}<0);
end
% Suppliers and Buyers of Nodes belonging to different category 
for t=1:39
    toc
    for i=1:length(FutureAbsent{t})
        Suppliers.FutureAbsent{t}{i}=predecessors(d_T{t},FutureAbsent{t}(i));
        Buyers.FutureAbsent{t}{i}=successors(d_T{t},FutureAbsent{t}(i));
    end
    for i=1:length(Constants{t})
        Suppliers.Constants{t}{i}=predecessors(d_T{t},Constants{t}(i));
        Buyers.Constants{t}{i}=successors(d_T{t},Constants{t}(i));
    end
    for i=1:length(MovedAway{t})
        Suppliers.MovedAway{t}{i}=predecessors(d_T{t},MovedAway{t}(i));
        Buyers.MovedAway{t}{i}=successors(d_T{t},MovedAway{t}(i));
    end
    for i=1:length(MovedCloser{t})
        Suppliers.MovedCloser{t}{i}=predecessors(d_T{t},MovedCloser{t}(i));
        Buyers.MovedCloser{t}{i}=successors(d_T{t},MovedCloser{t}(i));
    end
end
%status = -1; not in the network; = (0) not connected / (1) connected at (T-1)
for t=1:39
    toc
    for i=1:length(Constants{t})
       Suppliers.Constants_status{t}{i}=[];
       for k=1:length(Suppliers.Constants{t}{i})
           if findnode(d_T{t+1},Suppliers.Constants{t}{i}(k))>0
               Suppliers.Constants_status{t}{i}(k)=double(findedge(d_T{t+1},Suppliers.Constants{t}{i}(k),Constants{t}(i))>0);
           else
               Suppliers.Constants_status{t}{i}(k)=-1;
           end
       end
    end
end
for t=1:39
    toc
    for i=1:length(Constants{t})
       Buyers.Constants_status{t}{i}=[];
       for k=1:length(Buyers.Constants{t}{i})
           if findnode(d_T{t+1},Buyers.Constants{t}{i}(k))>0
               Buyers.Constants_status{t}{i}(k)=double(findedge(d_T{t+1},Constants{t}(i),Buyers.Constants{t}{i}(k))>0);
           else
               Buyers.Constants_status{t}{i}(k)=-1;
           end
       end
    end
end
% Set the tier-value for all sets of Nodes
%1. Past Absent; 2. Moved Closer 3. Moved Away 4. Constant
%5. Suppliers for Constant Nodes 6. Buyers for constant nodes
for t=1:39
    for i=1:length(FutureAbsent{t})
        FutureAbsent_Tier{t}(i)=TierMap{t}(FutureAbsent{t}{i});
    end
    for i=1:length(MovedCloser{t})
        MovedCloser_Tier{t}(i)=TierMap{t}(MovedCloser{t}{i});
    end
     for i=1:length(MovedAway{t})
        MovedAway_Tier{t}(i)=TierMap{t}(MovedAway{t}{i});
    end
    for i=1:length(Constants{t})
        Constants_Tier{t}(i)=TierMap{t}(Constants{t}{i});
    end
end
for t=1:39
    toc
    for i=1:length(Constants{t})
        Suppliers.Constants_Tier{t}{i}=[];
        for k=1:length(Suppliers.Constants{t}{i})
            Suppliers.Constants_Tier{t}{i}(k)=TierMap{t}(Suppliers.Constants{t}{i}{k});
        end
    end
end
for t=1:39
    toc
    for i=1:length(Constants{t})
        Buyers.Constants_Tiers{t}{i}=[];
        for k=1:length(Buyers.Constants{t}{i})
            Buyers.Constants_Tier{t}{i}(k)=TierMap{t}(Buyers.Constants{t}{i}{k});
        end
    end
end
% Number of Nodes 
% Overall
for t=1:39
    NumberofNodes.FutureAbsent(t)=length(FutureAbsent{t});
    NumberofNodes.MovedCloser(t)=length(MovedCloser{t});
    NumberofNodes.MovedAway(t)=length(MovedAway{t});
    NumberofNodes.Constants(t)=length(Constants{t});
    NumberofNodes.Total(t)=NumberofNodes.FutureAbsent(t)+NumberofNodes.MovedCloser(t)+NumberofNodes.MovedAway(t)+NumberofNodes.Constants(t);
end
% Tier-wise
for t=1:39
    for i=1:max(FutureAbsent_Tier{t})
        NumberofNodes.FutureAbsent_Tier{t}(i)=sum(FutureAbsent_Tier{t}==i);
    end
    for i=1:max(MovedCloser_Tier{t})
        NumberofNodes.MovedCloser_Tier{t}(i)=sum(MovedCloser_Tier{t}==i);
    end
    for i=1:max(MovedAway_Tier{t})
        NumberofNodes.MovedAway_Tier{t}(i)=sum(MovedAway_Tier{t}==i);
    end
    for i=1:max(Constants_Tier{t})
        NumberofNodes.Constants_Tier{t}(i)=sum(Constants_Tier{t}==i);
    end
    for i=1:max(supplier_distance_next{t})
        NumberofNodes.TierTotal{t}(i)=sum(supplier_distance_next{t}==i);
    end
end
% Number of Suppliers and Buyers in each node
for t=1:39
    toc
    for i=1:length(Constants{t})
        NumberofNodes.SupplierNum{t}(i)=length(Suppliers.Constants{t}{i});
        NumberofNodes.BuyerNum{t}(i)=length(Buyers.Constants{t}{i});
    end
end
% Number of Suppliers and Buyers- based on status and tier in each node
% i=1; status=-1; i=2; status=0; i=3; status=1;
% j repesent the tier
for t=1:39
    toc
    for i=1:length(Constants{t})
        NumberofNodes.SupplierNumStatus_Tier_wise{t}{i}=[];
        for j=1:max(Suppliers.Constants_Tier{t}{i})
            NumberofNodes.SupplierNumStatus_Tier_wise{t}{i}(1,j)=sum((Suppliers.Constants_status{t}{i}==-1).*(Suppliers.Constants_Tier{t}{i}==j));
            NumberofNodes.SupplierNumStatus_Tier_wise{t}{i}(2,j)=sum((Suppliers.Constants_status{t}{i}==0).*(Suppliers.Constants_Tier{t}{i}==j));
            NumberofNodes.SupplierNumStatus_Tier_wise{t}{i}(3,j)=sum((Suppliers.Constants_status{t}{i}==1).*(Suppliers.Constants_Tier{t}{i}==j));
        end
    end
end
for t=1:39
    toc
    for i=1:length(Constants{t})
        NumberofNodes.BuyerNumStatus_Tier_wise{t}{i}=[];
        for j=1:max(Buyers.Constants_Tier{t}{i})
            NumberofNodes.BuyerNumStatus_Tier_wise{t}{i}(1,j)=sum((Buyers.Constants_status{t}{i}==-1).*(Buyers.Constants_Tier{t}{i}==j));
            NumberofNodes.BuyerNumStatus_Tier_wise{t}{i}(2,j)=sum((Buyers.Constants_status{t}{i}==0).*(Buyers.Constants_Tier{t}{i}==j));
            NumberofNodes.BuyerNumStatus_Tier_wise{t}{i}(3,j)=sum((Buyers.Constants_status{t}{i}==1).*(Buyers.Constants_Tier{t}{i}==j));
        end
    end
end
% Summing the Nodes in tiers for the final data
for t=1:40
MaxTier(t)=max(supplier_distance_next{t});
end
Farthest_TierAllQuarters=max(MaxTier);
for t=1:39
    toc
    for j=1:Farthest_TierAllQuarters
        NumNodesFinal.Suppliers.Tier{t}{j}=zeros(3,Farthest_TierAllQuarters);
        for i=1:length(Constants{t})
            if Constants_Tier{t}(i)==j
                NumNodesFinal.Suppliers.Tier{t}{j}=NumNodesFinal.Suppliers.Tier{t}{j}+[NumberofNodes.SupplierNumStatus_Tier_wise{t}{i},zeros(3,Farthest_TierAllQuarters-size(NumberofNodes.SupplierNumStatus_Tier_wise{t}{i},2))];
            end
        end
    end
end
for t=1:39
    toc
    for j=1:Farthest_TierAllQuarters
        NumNodesFinal.Buyers.Tier{t}{j}=zeros(3,Farthest_TierAllQuarters);
        for i=1:length(Constants{t})
            if Constants_Tier{t}(i)==j
                NumNodesFinal.Buyers.Tier{t}{j}=NumNodesFinal.Buyers.Tier{t}{j}+[NumberofNodes.BuyerNumStatus_Tier_wise{t}{i},zeros(3,Farthest_TierAllQuarters-size(NumberofNodes.BuyerNumStatus_Tier_wise{t}{i},2))];
            end
        end
    end
end
%% In this section we analyse the network ties into the past. 
%% Nodes that are present/not present in last quarter
for t=2:40
    PastPresent{t}=NodesList{t}(ismember(NodesList{t},NodesList{t-1}));
    PastAbsent{t}=NodesList{t}(~ismember(NodesList{t},NodesList{t-1}));    
end
% Nodes that are present/not present in next quarter
for t=1:39
    FuturePresent{t}=NodesList{t}(ismember(NodesList{t},NodesList{t+1}));
    FutureAbsent{t}=NodesList{t}(~ismember(NodesList{t},NodesList{t+1}));    
end
% Change in tier for node that are present in last quarter
for t=2:40
    for i=1:length(PastPresent{t})
        TierChange{t}(i)=TierMap{t}(PastPresent{t}{i})-TierMap{t-1}(PastPresent{t}{i}); 
    end
end
% Nodes based on change in tier status, %1. Stayed at the same tier 
%2. Moved to farther tier, 3. Moved to closer tier
for t=2:40
    Constants{t}=PastPresent{t}(TierChange{t}==0);
    MovedAway{t}=PastPresent{t}(TierChange{t}>0);
    MovedCloser{t}=PastPresent{t}(TierChange{t}<0);
end
% Suppliers and Buyers of Nodes belonging to different category 
for t=2:40
    toc
    for i=1:length(PastAbsent{t})
        Suppliers.PastAbsent{t}{i}=predecessors(d_T{t},PastAbsent{t}(i));
        Buyers.PastAbsent{t}{i}=successors(d_T{t},PastAbsent{t}(i));
    end
    for i=1:length(Constants{t})
        Suppliers.Constants{t}{i}=predecessors(d_T{t},Constants{t}(i));
        Buyers.Constants{t}{i}=successors(d_T{t},Constants{t}(i));
    end
    for i=1:length(MovedAway{t})
        Suppliers.MovedAway{t}{i}=predecessors(d_T{t},MovedAway{t}(i));
        Buyers.MovedAway{t}{i}=successors(d_T{t},MovedAway{t}(i));
    end
    for i=1:length(MovedCloser{t})
        Suppliers.MovedCloser{t}{i}=predecessors(d_T{t},MovedCloser{t}(i));
        Buyers.MovedCloser{t}{i}=successors(d_T{t},MovedCloser{t}(i));
    end
end
%status = -1; not in the network; = (0) not connected / (1) connected at (T-1)
for t=2:40
    toc
    for i=1:length(Constants{t})
       Suppliers.Constants_status{t}{i}=[];
       for k=1:length(Suppliers.Constants{t}{i})
           if findnode(d_T{t-1},Suppliers.Constants{t}{i}(k))>0
               Suppliers.Constants_status{t}{i}(k)=double(findedge(d_T{t-1},Suppliers.Constants{t}{i}(k),Constants{t}(i))>0);
           else
               Suppliers.Constants_status{t}{i}(k)=-1;
           end
       end
    end
end
for t=2:40
    toc
    for i=1:length(Constants{t})
       Buyers.Constants_status{t}{i}=[];
       for k=1:length(Buyers.Constants{t}{i})
           if findnode(d_T{t-1},Buyers.Constants{t}{i}(k))>0
               Buyers.Constants_status{t}{i}(k)=double(findedge(d_T{t-1},Constants{t}(i),Buyers.Constants{t}{i}(k))>0);
           else
               Buyers.Constants_status{t}{i}(k)=-1;
           end
       end
    end
end
% Set the tier-value for all sets of Nodes
%1. Past Absent; 2. Moved Closer 3. Moved Away 4. Constant
%5. Suppliers for Constant Nodes 6. Buyers for constant nodes
for t=2:40
    for i=1:length(PastAbsent{t})
        PastAbsent_Tier{t}(i)=TierMap{t}(PastAbsent{t}{i});
    end
    for i=1:length(MovedCloser{t})
        MovedCloser_Tier{t}(i)=TierMap{t}(MovedCloser{t}{i});
    end
     for i=1:length(MovedAway{t})
        MovedAway_Tier{t}(i)=TierMap{t}(MovedAway{t}{i});
    end
    for i=1:length(Constants{t})
        Constants_Tier{t}(i)=TierMap{t}(Constants{t}{i});
    end
end
for t=2:40
    toc
    for i=1:length(Constants{t})
        Suppliers.Constants_Tier{t}{i}=[];
        for k=1:length(Suppliers.Constants{t}{i})
            Suppliers.Constants_Tier{t}{i}(k)=TierMap{t}(Suppliers.Constants{t}{i}{k});
        end
    end
end
for t=2:40
    toc
    for i=1:length(Constants{t})
        Buyers.Constants_Tiers{t}{i}=[];
        for k=1:length(Buyers.Constants{t}{i})
            Buyers.Constants_Tier{t}{i}(k)=TierMap{t}(Buyers.Constants{t}{i}{k});
        end
    end
end
% Number of Nodes 
% Overall
for t=2:40
    NumberofNodes.PastAbsent(t)=length(PastAbsent{t});
    NumberofNodes.MovedCloser(t)=length(MovedCloser{t});
    NumberofNodes.MovedAway(t)=length(MovedAway{t});
    NumberofNodes.Constants(t)=length(Constants{t});
    NumberofNodes.Total(t)=NumberofNodes.PastAbsent(t)+NumberofNodes.MovedCloser(t)+NumberofNodes.MovedAway(t)+NumberofNodes.Constants(t);
end
% Tier-wise
for t=2:40
    for i=1:max(PastAbsent_Tier{t})
        NumberofNodes.PastAbsent_Tier{t}(i)=sum(PastAbsent_Tier{t}==i);
    end
    for i=1:max(MovedCloser_Tier{t})
        NumberofNodes.MovedCloser_Tier{t}(i)=sum(MovedCloser_Tier{t}==i);
    end
    for i=1:max(MovedAway_Tier{t})
        NumberofNodes.MovedAway_Tier{t}(i)=sum(MovedAway_Tier{t}==i);
    end
    for i=1:max(Constants_Tier{t})
        NumberofNodes.Constants_Tier{t}(i)=sum(Constants_Tier{t}==i);
    end
    for i=1:max(supplier_distance_next{t})
        NumberofNodes.TierTotal{t}(i)=sum(supplier_distance_next{t}==i);
    end
end
% Number of Suppliers and Buyers in each node
for t=2:40
    toc
    for i=1:length(Constants{t})
        NumberofNodes.SupplierNum{t}(i)=length(Suppliers.Constants{t}{i});
        NumberofNodes.BuyerNum{t}(i)=length(Buyers.Constants{t}{i});
    end
end
% Number of Suppliers and Buyers- based on status and tier in each node
% i=1; status=-1; i=2; status=0; i=3; status=1;
% j repesent the tier
for t=2:40
    toc
    for i=1:length(Constants{t})
        NumberofNodes.SupplierNumStatus_Tier_wise{t}{i}=[];
        for j=1:max(Suppliers.Constants_Tier{t}{i})
            NumberofNodes.SupplierNumStatus_Tier_wise{t}{i}(1,j)=sum((Suppliers.Constants_status{t}{i}==-1).*(Suppliers.Constants_Tier{t}{i}==j));
            NumberofNodes.SupplierNumStatus_Tier_wise{t}{i}(2,j)=sum((Suppliers.Constants_status{t}{i}==0).*(Suppliers.Constants_Tier{t}{i}==j));
            NumberofNodes.SupplierNumStatus_Tier_wise{t}{i}(3,j)=sum((Suppliers.Constants_status{t}{i}==1).*(Suppliers.Constants_Tier{t}{i}==j));
        end
    end
end
for t=2:40
    toc
    for i=1:length(Constants{t})
        NumberofNodes.BuyerNumStatus_Tier_wise{t}{i}=[];
        for j=1:max(Buyers.Constants_Tier{t}{i})
            NumberofNodes.BuyerNumStatus_Tier_wise{t}{i}(1,j)=sum((Buyers.Constants_status{t}{i}==-1).*(Buyers.Constants_Tier{t}{i}==j));
            NumberofNodes.BuyerNumStatus_Tier_wise{t}{i}(2,j)=sum((Buyers.Constants_status{t}{i}==0).*(Buyers.Constants_Tier{t}{i}==j));
            NumberofNodes.BuyerNumStatus_Tier_wise{t}{i}(3,j)=sum((Buyers.Constants_status{t}{i}==1).*(Buyers.Constants_Tier{t}{i}==j));
        end
    end
end
% Summing the Nodes in tiers for the final data
for t=1:40
MaxTier(t)=max(supplier_distance_next{t});
end
Farthest_TierAllQuarters=max(MaxTier);
for t=2:40
    toc
    for j=1:Farthest_TierAllQuarters
        NumNodesFinal.Suppliers.Tier{t}{j}=zeros(3,Farthest_TierAllQuarters);
        for i=1:length(Constants{t})
            if Constants_Tier{t}(i)==j
                NumNodesFinal.Suppliers.Tier{t}{j}=NumNodesFinal.Suppliers.Tier{t}{j}+[NumberofNodes.SupplierNumStatus_Tier_wise{t}{i},zeros(3,Farthest_TierAllQuarters-size(NumberofNodes.SupplierNumStatus_Tier_wise{t}{i},2))];
            end
        end
    end
end
for t=2:40
    toc
    for j=1:Farthest_TierAllQuarters
        NumNodesFinal.Buyers.Tier{t}{j}=zeros(3,Farthest_TierAllQuarters);
        for i=1:length(Constants{t})
            if Constants_Tier{t}(i)==j
                NumNodesFinal.Buyers.Tier{t}{j}=NumNodesFinal.Buyers.Tier{t}{j}+[NumberofNodes.BuyerNumStatus_Tier_wise{t}{i},zeros(3,Farthest_TierAllQuarters-size(NumberofNodes.BuyerNumStatus_Tier_wise{t}{i},2))];
            end
        end
    end
end