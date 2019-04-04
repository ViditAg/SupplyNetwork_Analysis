function zeta=Hzeta(x,alpha)
Infinity=0:1:1e5;
zeta=sum((Infinity+x).^(-alpha));