tic
rng('shuffle')
% load the indegree and outdegree distribution data already calculated
load('Indegree_Outdegree_Data.mat'); 
i=1;t=50;
Infinity=0:1:1e5;
Input_data=Indegree_ListT7{Company_i,Quarter_t}(Indegree_ListT7{Company_i,Quarter_t}>0);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%Start Power-Law degree exponent calculation%%%%%%%%%%%%%%%%%%%%%
k_minimum=min(Input_data);
k_maximum=max(Input_data);
bins_data=linspace(k_minimum,k_maximum,k_maximum-k_minimum+1);
h_data=hist(Input_data,bins_data);
PDF_data=h_data/sum(h_data);
for i=1:length(PDF_data)
    CDF_data(i)=sum(PDF_data(1:i));
end
K_list=k_minimum:1:k_maximum;
N=length(Input_data);
for K_loop=1:length(K_list)
    toc
    K_min=K_list(K_loop);
    Gamma(K_loop)=1+(N/sum(log(K_list/(K_min - 0.5))));
    Hzeta_Kmin=Hzeta(K_min,Gamma(K_loop));
    for zetaloop=1:length(K_list)
        CDF_fit{K_loop}(zetaloop)=1 - (Hzeta(K_list(zetaloop),Gamma(K_loop))./Hzeta_Kmin);
    end
    D(K_loop)=max(abs(CDF_data(K_loop:end) - CDF_fit{K_loop}(K_loop:end)));
end
[minD,minDid]=min(D);
K_minD=K_list(minDid);
Gamma_minD=Gamma(minDid);% degree exponent
InfinityPrime=Infinity(3:end)+K_minD;
zetapre=InfinityPrime.^(-Gamma_minD);
zetaprime=sum(log(InfinityPrime).*zetapre);
zetadoubleprime=sum((log(InfinityPrime).^2).*zetapre);
Std_error=1/sqrt(N*((zetadoubleprime/Hzeta(K_minD,Gamma_minD))-(zetaprime/Hzeta(K_minD,Gamma_minD))^2)); % standard error
for zetaloop=1:length(K_list)
PDF_minD(zetaloop)=(K_list(zetaloop)^(-Gamma_minD))/Hzeta(K_minD,Gamma_minD);
end
PDF_minD=PDF_minD(minDid:end);
CDF_minD=CDF_fit{minDid}(minDid:end);
%%%%%%%%Goodness of the fit%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
for i=1:length(PDF_minD)
    Dk_PDF(i)=sum(PDF_minD(i:end));
end
M=1e4;
bins_syn=bins_data(minDid:end);
for j=1:M
    toc
    randlist=rand(N,1);
    k_syn_seq=zeros(N,1);
    for i=1:length(Dk_PDF)-1
       imask=logical((randlist<Dk_PDF(i)).*(randlist>Dk_PDF(i+1)));
        k_syn_seq(imask)=i+K_minD-1;
    end
    imask=(randlist<Dk_PDF(length(Dk_PDF)));
    k_syn_seq(imask)=length(Dk_PDF)+K_minD-1;
    h_syn=hist(k_syn_seq,bins_syn); 
    PDF_syn=h_syn/sum(h_syn);
    for i=1:length(PDF_syn)
        CDF_syn(i)=sum(PDF_syn(1:i));
    end
    D_syn(j)=max(abs(CDF_syn - CDF_data(minDid:end)));
end
bins_Dsyn=linspace(min(D_syn),max(D_syn),50);
h_Dsyn=hist(D_syn,bins_Dsyn);
p_D_syn=sum(D_syn>minD)/length(D_syn);
GoodorBad=(minD>min(D_syn)).*(minD<max(D_syn));

Indegree_data=Indegree_ListT5{3,1}(Indegree_ListT5{3,1}>0);

hold on;

bins_data=linspace(min(Indegree_data),max(Indegree_data),max(Indegree_data)-min(Indegree_data)+1);
h_data=hist(Indegree_data,bins_data)/sum(hist(Indegree_data,bins_data));
subplot(2,1,1)
loglog(bins_data,h_data,'.r');
hold on;
plot(K_list(2:end),PDF_minD);
for i=1:length(h_data)
    CDF_data(i)=sum(h_data(1:i));
end
subplot(2,1,2)
plot(bins_data,CDF_data);
hold on;
plot(K_list(2:end),CDF_minD);
plot(K_list,D);