load('SupplyChain_data.mat'); % Load FactSet Dataset
COMPANY={'10953'}; %FactSet ID of the Focal company
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
    % identifying all nodes with Euclidean distance from focal company> 3
    company_imaskT3{t}=supplier_distance_next{t}>3;
    % identifying all nodes with Euclidean distance from focal company > 7
    company_imaskT7{t}=supplier_distance_next{t}>7;
    % subsetting the supply network so that 
    %the greatest euclidean distance from focal company = 3
    % we call this a 3-Tier supply network of focal company
    d_T3{t}=rmnode(d_T{t},table2array(d_T{t}.Nodes(company_imaskT3{t},1)));
    % the greatest euclidean distance from focal company = 7
    % we call this a 3-Tier supply network of focal company
    d_T7{t}=rmnode(d_T{t},table2array(d_T{t}.Nodes(company_imaskT7{t},1)));
    % Get the list of indgree of every node in the subsetted network
    % 3-Tier supply network
    Indegree_ListT3{t}=indegree(d_T3{t});
    % 7-Tier supply network
    Indegree_ListT7{t}=indegree(d_T7{t});
    % Get the list of indgree of every node in the subsetted network
    % 3-Tier supply network
    Outdegree_ListT3{t}=outdegree(d_T3{t});
    % 7-Tier supply network
    Outdegree_ListT7{t}=outdegree(d_T7{t});
end