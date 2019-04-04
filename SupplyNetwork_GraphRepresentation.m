% Load the Supply netework digraphs
load('SupplyNetwork_digraph_data.mat'); 
tic
COMPANY=('10953');% Company ID whose supply network we want to plot
Quarter=1; % Quarter for which we want to plot
Network=Supply_Network{Quarter};
inode=findnode(Network,COMPANY);
map = single(distances(Network));
map(~isfinite(map))=0;
supplier_distance=map(:,inode); % array for supplier distances
company_imask=supplier_distance>0;
company_imask(inode,1)=1;
d_T=rmnode(Network,table2array(Network.Nodes(~company_imask,1)));
map_next = single(distances(d_T));
map_next(~isfinite(map_next))=0;
inode_next=findnode(d_T,COMPANY);
supplier_distance_next=map_next(:,inode_next);
%%%%%%%%%%%%%%%%%%%%%
%Uncomment the syntax for whichever tier-network you want to show
%%%%%%%%%%%%%%%%%%%%%
% company_imaskT1=supplier_distance_next>1;
% d_T1=rmnode(d_T,table2array(d_T.Nodes(company_imaskT1,1)));
% inode_T1=findnode(d_T1,COMPANY);
% map_next = single(distances(d_T1));
% map_next(~isfinite(map_next))=0;
% inode_next=inode_T1;
% supplier_distance_next=map_next(:,inode_next);
% d_T=d_T1;
% %%%%%%%%%%%%%%%%%%%%%
% company_imaskT2=supplier_distance_next>2;
% d_T2=rmnode(d_T,table2array(d_T.Nodes(company_imaskT2,1)));
% inode_T2=findnode(d_T2,COMPANY);
% map_next = single(distances(d_T2));
% map_next(~isfinite(map_next))=0;
% inode_next=inode_T2;
% supplier_distance_next=map_next(:,inode_next);
% d_T=d_T2;
% %%%%%%%%%%%%%%%%%%%%%
% company_imaskT3=supplier_distance_next>3;
% d_T3=rmnode(d_T,table2array(d_T.Nodes(company_imaskT3,1)));
% inode_T3=findnode(d_T3,COMPANY);
% map_next = single(distances(d_T3));
% map_next(~isfinite(map_next))=0;
% inode_next=inode_T3;
% supplier_distance_next=map_next(:,inode_next);
% d_T=d_T3;
% %%%%%%%%%%%%%%%%%%%%%
company_imaskT4=supplier_distance_next>4;
d_T4=rmnode(d_T,table2array(d_T.Nodes(company_imaskT4,1)));
inode_T4=findnode(d_T4,COMPANY);
map_next = single(distances(d_T4));
map_next(~isfinite(map_next))=0;
inode_next=inode_T4;
supplier_distance_next=map_next(:,inode_next);
d_T=d_T4;
%%%%%%%%%%%%%%%%%%%%%       
pl=plot(d_T,'NodeColor','w','EdgeColor','b','MarkerSize',0.000001);
highlight(pl,'10953','MarkerSize',6,'NodeColor','y')
labelnode(pl,'10953','')
labelnode(pl,d_T.Nodes{1:inode_next-1,1},'')
labelnode(pl,d_T.Nodes{inode_next+1:end,1},'')
for i=1:size(d_T.Nodes,1)
    toc
    if i==inode_next
        pl.XData(inode_next)=0;
        pl.YData(inode_next)=0;
        pl.ZData(inode_next)=0;
    else
        if i<inode_next
            ii=i;
        else
            ii=i+1;
        end
        if supplier_distance_next(i)~=0
            pl.XData(i)=3*supplier_distance_next(i)*cos(2*pi*ii/size(d_T.Nodes,1));
            pl.YData(i)=3*supplier_distance_next(i)*sin(2*pi*ii/size(d_T.Nodes,1));
            pl.ZData(i)=0;
            highlight(pl,d_T.Nodes{i,1},'NodeColor','k','Markersize',4);
        else
            pred_list=predecessors(d_T,d_T.Nodes{i,1});
            for lp=1:length(pred_list)
                if supplier_distance_next(findnode(d_T,pred_list{lp}))~=0
                    pl.XData(i)=1.5*supplier_distance_next(findnode(d_T,pred_list{lp}))*cos(2*pi*findnode(d_T,pred_list{lp})/size(d_T.Nodes,1));
                    pl.YData(i)=1.5*supplier_distance_next(findnode(d_T,pred_list{lp}))*sin(2*pi*findnode(d_T,pred_list{lp})/size(d_T.Nodes,1));
                    pl.ZData(i)=0;
                    highlight(pl,d_T.Nodes{i,1},'NodeColor','w','Markersize',0.00000001);
                end
            end
        end
    end
end