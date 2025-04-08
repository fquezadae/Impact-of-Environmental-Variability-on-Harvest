


clear
clear global
% clc
tic

format short g
format compact

% **********************************************************
% import data from stata

gear2betaimport=importdata('D:\data\cost_cs_sur_rescaled_fe_gear2beta.txt','\t');
gear2beta=gear2betaimport.data;
gear2betalabel=gear2betaimport.textdata;

gear3betaimport=importdata('D:\data\cost_cs_sur_rescaled_fe_gear3beta.txt','\t');
gear3beta=gear3betaimport.data;
gear3betalabel=gear3betaimport.textdata;

gear4betaimport=importdata('D:\data\cost_cs_sur_rescaled_fe_gear4beta.txt','\t');
gear4beta=gear4betaimport.data;
gear4betalabel=gear4betaimport.textdata;

gear5betaimport=importdata('D:\data\cost_cs_sur_rescaled_fe_gear5beta.txt','\t');
gear5beta=gear5betaimport.data;
gear5betalabel=gear5betaimport.textdata;



gear2poissonbetaimport=importdata('D:\data\gear2poissonbeta_rescaled_fe.txt','\t');
gear2poissonbeta=gear2poissonbetaimport.data;
gear2poissonbetalabel=gear2poissonbetaimport.textdata;

gear3poissonbetaimport=importdata('D:\data\gear3poissonbeta_rescaled_fe.txt','\t');
gear3poissonbeta=gear3poissonbetaimport.data;
gear3poissonbetalabel=gear3poissonbetaimport.textdata;

gear4poissonbetaimport=importdata('D:\data\gear4poissonbeta_rescaled_fe.txt','\t');
gear4poissonbeta=gear4poissonbetaimport.data;
gear4poissonbetalabel=gear4poissonbetaimport.textdata;

gear5poissonbetaimport=importdata('D:\data\gear5poissonbeta_rescaled_fe.txt','\t');
gear5poissonbeta=gear5poissonbetaimport.data;
gear5poissonbetalabel=gear5poissonbetaimport.textdata;




gear2poissonmarginalimport=importdata('D:\data\gear2poissonmarginal_rescaled_fe.txt','\t');
gear2poissonmarginal=gear2poissonmarginalimport.data;
gear2poissonmarginallabel=gear2poissonmarginalimport.textdata;

gear3poissonmarginalimport=importdata('D:\data\gear3poissonmarginal_rescaled_fe.txt','\t');
gear3poissonmarginal=gear3poissonmarginalimport.data;
gear3poissonmarginallabel=gear3poissonmarginalimport.textdata;

gear4poissonmarginalimport=importdata('D:\data\gear4poissonmarginal_rescaled_fe.txt','\t');
gear4poissonmarginal=gear4poissonmarginalimport.data;
gear4poissonmarginallabel=gear4poissonmarginalimport.textdata;

gear5poissonmarginalimport=importdata('D:\data\gear5poissonmarginal_rescaled_fe.txt','\t');
gear5poissonmarginal=gear5poissonmarginalimport.data;
gear5poissonmarginallabel=gear5poissonmarginalimport.textdata;

cvpoissonmarginal=[gear2poissonmarginal' gear3poissonmarginal' gear4poissonmarginal' gear5poissonmarginal'];


CPgear2betaimport=importdata('D:\data\CP_cost_cs_sur_rescaled_fe_gear2beta.txt','\t');
CPgear2beta=CPgear2betaimport.data;
CPgear2betalabel=CPgear2betaimport.textdata;

CPgear3betaimport=importdata('D:\data\CP_cost_cs_sur_rescaled_fe_gear3beta.txt','\t');
CPgear3beta=CPgear3betaimport.data;
CPgear3betalabel=CPgear3betaimport.textdata;

CPgear4betaimport=importdata('D:\data\CP_cost_cs_sur_rescaled_fe_gear4beta.txt','\t');
CPgear4beta=CPgear4betaimport.data;
CPgear4betalabel=CPgear4betaimport.textdata;

CPgear5betaimport=importdata('D:\data\CP_cost_cs_sur_rescaled_fe_gear5beta.txt','\t');
CPgear5beta=CPgear5betaimport.data;
CPgear5betalabel=CPgear5betaimport.textdata;


CPgear2poissonbetaimport=importdata('D:\data\CP_gear2poissonbeta_rescaled_fe.txt','\t');
CPgear2poissonbeta=CPgear2poissonbetaimport.data;
CPgear2poissonbetalabel=CPgear2poissonbetaimport.textdata;

CPgear3poissonbetaimport=importdata('D:\data\CP_gear3poissonbeta_rescaled_fe.txt','\t');
CPgear3poissonbeta=CPgear3poissonbetaimport.data;
CPgear3poissonbetalabel=CPgear3poissonbetaimport.textdata;

CPgear4poissonbetaimport=importdata('D:\data\CP_gear4poissonbeta_rescaled_fe.txt','\t');
CPgear4poissonbeta=CPgear4poissonbetaimport.data;
CPgear4poissonbetalabel=CPgear4poissonbetaimport.textdata;

CPgear5poissonbetaimport=importdata('D:\data\CP_gear5poissonbeta_rescaled_fe.txt','\t');
CPgear5poissonbeta=CPgear5poissonbetaimport.data;
CPgear5poissonbetalabel=CPgear5poissonbetaimport.textdata;





CPgear2poissonmarginalimport=importdata('D:\data\CP_gear2poissonmarginal_rescaled_fe.txt','\t');
CPgear2poissonmarginal=CPgear2poissonmarginalimport.data;
CPgear2poissonmarginallabel=CPgear2poissonmarginalimport.textdata;

CPgear3poissonmarginalimport=importdata('D:\data\CP_gear3poissonmarginal_rescaled_fe.txt','\t');
CPgear3poissonmarginal=CPgear3poissonmarginalimport.data;
CPgear3poissonmarginallabel=CPgear3poissonmarginalimport.textdata;

CPgear4poissonmarginalimport=importdata('D:\data\CP_gear4poissonmarginal_rescaled_fe.txt','\t');
CPgear4poissonmarginal=CPgear4poissonmarginalimport.data;
CPgear4poissonmarginallabel=CPgear4poissonmarginalimport.textdata;

CPgear5poissonmarginalimport=importdata('D:\data\CP_gear5poissonmarginal_rescaled_fe.txt','\t');
CPgear5poissonmarginal=CPgear5poissonmarginalimport.data;
CPgear5poissonmarginallabel=CPgear5poissonmarginalimport.textdata;

cppoissonmarginal=[CPgear2poissonmarginal' CPgear3poissonmarginal' CPgear4poissonmarginal' CPgear5poissonmarginal'];


gear2Vimport=importdata('D:\data\cost_cs_sur_rescaled_fe_gear2V.txt','\t');
gear2V=gear2Vimport.data;
gear2Vlabel=gear2Vimport.textdata;

gear3Vimport=importdata('D:\data\cost_cs_sur_rescaled_fe_gear3V.txt','\t');
gear3V=gear3Vimport.data;
gear3Vlabel=gear3Vimport.textdata;

gear4Vimport=importdata('D:\data\cost_cs_sur_rescaled_fe_gear4V.txt','\t');
gear4V=gear4Vimport.data;
gear4Vlabel=gear4Vimport.textdata;

gear5Vimport=importdata('D:\data\cost_cs_sur_rescaled_fe_gear5V.txt','\t');
gear5V=gear5Vimport.data;
gear5Vlabel=gear5Vimport.textdata;



gear2poissonVimport=importdata('D:\data\gear2poissonV_rescaled_fe.txt','\t');
gear2poissonV=gear2poissonVimport.data;
gear2poissonVlabel=gear2poissonVimport.textdata;

gear3poissonVimport=importdata('D:\data\gear3poissonV_rescaled_fe.txt','\t');
gear3poissonV=gear3poissonVimport.data;
gear3poissonVlabel=gear3poissonVimport.textdata;

gear4poissonVimport=importdata('D:\data\gear4poissonV_rescaled_fe.txt','\t');
gear4poissonV=gear4poissonVimport.data;
gear4poissonVlabel=gear4poissonVimport.textdata;

gear5poissonVimport=importdata('D:\data\gear5poissonV_rescaled_fe.txt','\t');
gear5poissonV=gear5poissonVimport.data;
gear5poissonVlabel=gear5poissonVimport.textdata;




gear2poissonmarginalVimport=importdata('D:\data\gear2poissonmarginalV_rescaled_fe.txt','\t');
gear2poissonmarginalV=gear2poissonmarginalVimport.data;
gear2poissonmarginalVlabel=gear2poissonmarginalVimport.textdata;

gear3poissonmarginalVimport=importdata('D:\data\gear3poissonmarginalV_rescaled_fe.txt','\t');
gear3poissonmarginalV=gear3poissonmarginalVimport.data;
gear3poissonmarginalVlabel=gear3poissonmarginalVimport.textdata;

gear4poissonmarginalVimport=importdata('D:\data\gear4poissonmarginalV_rescaled_fe.txt','\t');
gear4poissonmarginalV=gear4poissonmarginalVimport.data;
gear4poissonmarginalVlabel=gear4poissonmarginalVimport.textdata;

gear5poissonmarginalVimport=importdata('D:\data\gear5poissonmarginalV_rescaled_fe.txt','\t');
gear5poissonmarginalV=gear5poissonmarginalVimport.data;
gear5poissonmarginalVlabel=gear5poissonmarginalVimport.textdata;

CPgear2Vimport=importdata('D:\data\CP_cost_cs_sur_rescaled_fe_gear2V.txt','\t');
CPgear2V=CPgear2Vimport.data;
CPgear2Vlabel=CPgear2Vimport.textdata;

CPgear3Vimport=importdata('D:\data\CP_cost_cs_sur_rescaled_fe_gear3V.txt','\t');
CPgear3V=CPgear3Vimport.data;
CPgear3Vlabel=CPgear3Vimport.textdata;

CPgear4Vimport=importdata('D:\data\CP_cost_cs_sur_rescaled_fe_gear4V.txt','\t');
CPgear4V=CPgear4Vimport.data;
CPgear4Vlabel=CPgear4Vimport.textdata;

CPgear5Vimport=importdata('D:\data\CP_cost_cs_sur_rescaled_fe_gear5V.txt','\t');
CPgear5V=CPgear5Vimport.data;
CPgear5Vlabel=CPgear5Vimport.textdata;


CPgear2poissonVimport=importdata('D:\data\CP_gear2poissonV_rescaled_fe.txt','\t');
CPgear2poissonV=CPgear2poissonVimport.data;
CPgear2poissonVlabel=CPgear2poissonVimport.textdata;

CPgear3poissonVimport=importdata('D:\data\CP_gear3poissonV_rescaled_fe.txt','\t');
CPgear3poissonV=CPgear3poissonVimport.data;
CPgear3poissonVlabel=CPgear3poissonVimport.textdata;

CPgear4poissonVimport=importdata('D:\data\CP_gear4poissonV_rescaled_fe.txt','\t');
CPgear4poissonV=CPgear4poissonVimport.data;
CPgear4poissonVlabel=CPgear4poissonVimport.textdata;

CPgear5poissonVimport=importdata('D:\data\CP_gear5poissonV_rescaled_fe.txt','\t');
CPgear5poissonV=CPgear5poissonVimport.data;
CPgear5poissonVlabel=CPgear5poissonVimport.textdata;


CPgear2poissonmarginalVimport=importdata('D:\data\CP_gear2poissonmarginalV_rescaled_fe.txt','\t');
CPgear2poissonmarginalV=CPgear2poissonmarginalVimport.data;
CPgear2poissonmarginalVlabel=CPgear2poissonmarginalVimport.textdata;

CPgear3poissonmarginalVimport=importdata('D:\data\CP_gear3poissonmarginalV_rescaled_fe.txt','\t');
CPgear3poissonmarginalV=CPgear3poissonmarginalVimport.data;
CPgear3poissonmarginalVlabel=CPgear3poissonmarginalVimport.textdata;

CPgear4poissonmarginalVimport=importdata('D:\data\CP_gear4poissonmarginalV_rescaled_fe.txt','\t');
CPgear4poissonmarginalV=CPgear4poissonmarginalVimport.data;
CPgear4poissonmarginalVlabel=CPgear4poissonmarginalVimport.textdata;

CPgear5poissonmarginalVimport=importdata('D:\data\CP_gear5poissonmarginalV_rescaled_fe.txt','\t');
CPgear5poissonmarginalV=CPgear5poissonmarginalVimport.data;
CPgear5poissonmarginalVlabel=CPgear5poissonmarginalVimport.textdata;


% set up all the parameters for the X data as globals
global cv_p1;
global cv_p2;
global cv_p3;
global cv_p4;
for j=2:5
    j=int2str(j);
    for i=1:3
        i=int2str(i);
        eval(sprintf('%s','global cv_g',j,'h',i,';'));
        i=str2num(i);
    end
    j=str2num(j);
end
global cv_z4;
global cv_z5;
global cv_z6;


importcsvfile('D:\data\cost_cs_sur_rescaled_fe_X2009.csv');
profitXmat2009=csvread('D:\data\cost_cs_sur_rescaled_fe_X2009nonames.csv');
global npx;
[npx,kpx]=size(profitXmat2009);

global cvgearever;
cvgearever=[cv_gear2ever cv_gear3ever cv_gear4ever cv_gear5ever];
global cvgearyear;
cvgearyear=[cv_gear2year cv_gear3year cv_gear4year cv_gear5year];
global cvtottrips
cvtottrips=[cv_tottripsgear2 cv_tottripsgear3 cv_tottripsgear4 cv_tottripsgear5 ];


% set up all the parameters for the X data as globals
global cp_p1;
global cp_p2;
global cp_p3;
global cp_p4;
for j=2:5
    j=int2str(j);
    for i=1:3
        i=int2str(i);
        eval(sprintf('%s','global cp_g',j,'h',i,';'));
        i=str2num(i);
    end
    j=str2num(j);
end
global cp_z4;
global cp_z5;
global cp_z6;

importcsvfile('D:\data\CP_cost_cs_sur_rescaled_fe_X2009.csv');
CPprofitXmat2009=csvread('D:\data\CP_cost_cs_sur_rescaled_fe_X2009nonames.csv');
global npxcp;
[npxcp,kpxcp]=size(CPprofitXmat2009);


global cpgearever;
cpgearever=[cp_gear2ever cp_gear3ever cp_gear4ever cp_gear5ever];
global cpgearyear;
cpgearyear=[cp_gear2year cp_gear3year cp_gear4year cp_gear5year];
global cptotweeks
cptotweeks=[cp_weeksgear2 cp_weeksgear3 cp_weeksgear4 cp_weeksgear5 ];




global bsaistock1;
global bsaistock2;
global bsaistock3;
global bsaitac1;
global bsaitac2;
global bsaitac3;
global stock_year;
importcsvfile('D:\ESBFM\AFSC\2009\tacchartdata_matlab.csv');



importcsvfile('D:\data\cv_harvest_shares_rescaled_fe.csv');
for j=2:5
    j=int2str(j);
    for i=1:3
        i=int2str(i);
        eval(sprintf('%s','global cv_indshareg',j,'h',i,';'));
        eval(sprintf('%s','cv_indshareg',j,'h',i,'=indshareg',j,'h',i,';'));
        eval(sprintf('%s','clear indshareg',j,'h',i,';'));
        i=str2num(i);
    end
    j=str2num(j);
end

importcsvfile('D:\data\cp_harvest_shares_rescaled_fe.csv');
for j=2:5
    j=int2str(j);
    for i=1:3
        i=int2str(i);
        eval(sprintf('%s','global cp_indshareg',j,'h',i,';'));
        eval(sprintf('%s','cp_indshareg',j,'h',i,'=indshareg',j,'h',i,';'));
        eval(sprintf('%s','clear indshareg',j,'h',i,';'));
        i=str2num(i);
    end
    j=str2num(j);
end
clear adfg i j

gearshareimport=importdata('D:\data\gearshare_rescaled_fe.txt','\t');
global gearshare;
gearshare=gearshareimport.data;
gearsharelabel=gearshareimport.textdata;


ms_betaimport=importdata('D:\data\ms_growth.txt','\t');
global ms_beta;
ms_beta=ms_betaimport.data;
ms_betalabel=ms_betaimport.textdata;

ms_Vimport=importdata('D:\data\ms_growthV.txt','\t');
global ms_V;
ms_V=ms_Vimport.data;
ms_Vlabel=ms_Vimport.textdata;

ms_sigmaimport=importdata('D:\data\ms_growthsigma.txt','\t');
ms_sigma=ms_sigmaimport.data;
ms_sigmalabel=ms_sigmaimport.textdata;

ss_beta1import=importdata('D:\data\ss_growth1.txt','\t');
global ss_beta1;
ss_beta1=ss_beta1import.data;
ss_beta1label=ss_beta1import.textdata;

ss_V1import=importdata('D:\data\ss_growth1V.txt','\t');
global ss_V1;
ss_V1=ss_V1import.data;
ss_V1label=ss_V1import.textdata;

ss_beta2import=importdata('D:\data\ss_growth2.txt','\t');
global ss_beta2;
ss_beta2=ss_beta2import.data;
ss_beta2label=ss_beta2import.textdata;

ss_V2import=importdata('D:\data\ss_growth2V.txt','\t');
global ss_V2;
ss_V2=ss_V2import.data;
ss_V2label=ss_V2import.textdata;

ss_beta3import=importdata('D:\data\ss_growth3.txt','\t');
global ss_beta3;
ss_beta3=ss_beta3import.data;
ss_beta3label=ss_beta3import.textdata;

ss_V3import=importdata('D:\data\ss_growth3V.txt','\t');
global ss_V3;
ss_V3=ss_V3import.data;
ss_V3label=ss_V3import.textdata;


clear bsaicatch1 bsaicatch2 bsaicatch3 ;
importcsvfile('D:\data\projectedprices_pr.csv');
importcsvfile('D:\data\projectedprices_pc.csv');
global bsaiaveprice1 bsaiaveprice2 bsaiaveprice3 bsaicatch1 bsaicatch2 bsaicatch3 ;
importcsvfile('D:\data\stockpricecatch.csv');

pricebetaimport=importdata('D:\data\pricebeta.txt','\t');
pricebeta=pricebetaimport.data;
pricebetalabel=pricebetaimport.textdata;

priceVimport=importdata('D:\data\priceV.txt','\t');
priceV=priceVimport.data;
priceVlabel=priceVimport.textdata;

global pricebeta1 pricebeta2 pricebeta3 ;
pricebeta1=zeros(5,1);
pricebeta2=zeros(5,1);
pricebeta3=zeros(5,1);
pricebetahat=zeros(size(pricebeta));

global cvbeta;
global cvpoissonbeta;
global cpbeta;
global cppoissonbeta;

cvbeta=zeros(77,4);
cvpoissonbeta=zeros(14,4);
cpbeta=zeros(77,4);
cppoissonbeta=zeros(14,4);


% set up email 
myaddress = '';
mypassword = '';

setpref('Internet','E_mail',myaddress);
setpref('Internet','SMTP_Server','smtp.gmail.com');
setpref('Internet','SMTP_Username',myaddress);
setpref('Internet','SMTP_Password',mypassword);

props = java.lang.System.getProperties;
props.setProperty('mail.smtp.auth','true');
props.setProperty('mail.smtp.socketFactory.class', ...
                  'javax.net.ssl.SSLSocketFactory');
props.setProperty('mail.smtp.socketFactory.port','465');


% ************************************************************
% Parameter set up
% ************************************************************




global Y;
Y=25;
global gt;
gt=4;
global theta;
theta=.05;
global sim;
sim=100;

suffix='_fe';
basepath='D:\ESBFM\Data\individual years\Normalized Quadratic\crewservices\FE\';

global coefnum;
coefnum=77;
global costreg;
costreg=66;

% set up the Fixed effects
global cv_FE
global CP_FE
cv_FE=zeros(npx,gt);
CP_FE=zeros(npxcp,gt);

cv_FE(7,1)=gear2beta(28);
cv_FE(8,1)=gear2beta(29);
cv_FE(98,1)=gear2beta(30);
cv_FE(124,1)=gear2beta(31);
cv_FE(152,1)=gear2beta(32);
cv_FE(169,1)=gear2beta(33);
cv_FE(172,1)=gear2beta(34);
cv_FE(183,1)=gear2beta(35);
cv_FE(228,1)=gear2beta(36);
cv_FE(243,1)=gear2beta(37);
cv_FE(247,1)=gear2beta(38);
cv_FE(253,1)=gear2beta(39);
cv_FE(285,1)=gear2beta(40);
cv_FE(338,1)=gear2beta(41);
cv_FE(339,1)=gear2beta(42);
cv_FE(345,1)=gear2beta(43);
cv_FE(348,1)=gear2beta(44);
cv_FE(377,1)=gear2beta(45);
cv_FE(5,2)=gear3beta(66);
cv_FE(10,2)=gear3beta(67);
cv_FE(16,2)=gear3beta(68);
cv_FE(20,2)=gear3beta(69);
cv_FE(21,2)=gear3beta(70);
cv_FE(27,2)=gear3beta(71);
cv_FE(29,2)=gear3beta(72);
cv_FE(34,2)=gear3beta(73);
cv_FE(39,2)=gear3beta(74);
cv_FE(47,2)=gear3beta(75);
cv_FE(64,2)=gear3beta(76);
cv_FE(66,2)=gear3beta(77);
cv_FE(74,2)=gear3beta(78);
cv_FE(80,2)=gear3beta(79);
cv_FE(81,2)=gear3beta(80);
cv_FE(84,2)=gear3beta(81);
cv_FE(86,2)=gear3beta(82);
cv_FE(88,2)=gear3beta(83);
cv_FE(109,2)=gear3beta(84);
cv_FE(111,2)=gear3beta(85);
cv_FE(120,2)=gear3beta(86);
cv_FE(121,2)=gear3beta(87);
cv_FE(125,2)=gear3beta(88);
cv_FE(127,2)=gear3beta(89);
cv_FE(130,2)=gear3beta(90);
cv_FE(137,2)=gear3beta(91);
cv_FE(140,2)=gear3beta(92);
cv_FE(142,2)=gear3beta(93);
cv_FE(146,2)=gear3beta(94);
cv_FE(156,2)=gear3beta(95);
cv_FE(162,2)=gear3beta(96);
cv_FE(176,2)=gear3beta(97);
cv_FE(192,2)=gear3beta(98);
cv_FE(195,2)=gear3beta(99);
cv_FE(197,2)=gear3beta(100);
cv_FE(201,2)=gear3beta(101);
cv_FE(203,2)=gear3beta(102);
cv_FE(207,2)=gear3beta(103);
cv_FE(210,2)=gear3beta(104);
cv_FE(211,2)=gear3beta(105);
cv_FE(213,2)=gear3beta(106);
cv_FE(215,2)=gear3beta(107);
cv_FE(216,2)=gear3beta(108);
cv_FE(222,2)=gear3beta(109);
cv_FE(251,2)=gear3beta(110);
cv_FE(261,2)=gear3beta(111);
cv_FE(275,2)=gear3beta(112);
cv_FE(278,2)=gear3beta(113);
cv_FE(286,2)=gear3beta(114);
cv_FE(292,2)=gear3beta(115);
cv_FE(297,2)=gear3beta(116);
cv_FE(298,2)=gear3beta(117);
cv_FE(311,2)=gear3beta(118);
cv_FE(313,2)=gear3beta(119);
cv_FE(315,2)=gear3beta(120);
cv_FE(320,2)=gear3beta(121);
cv_FE(326,2)=gear3beta(122);
cv_FE(335,2)=gear3beta(123);
cv_FE(340,2)=gear3beta(124);
cv_FE(344,2)=gear3beta(125);
cv_FE(349,2)=gear3beta(126);
cv_FE(352,2)=gear3beta(127);
cv_FE(357,2)=gear3beta(128);
cv_FE(361,2)=gear3beta(129);
cv_FE(362,2)=gear3beta(130);
cv_FE(364,2)=gear3beta(131);
cv_FE(370,2)=gear3beta(132);
cv_FE(3,3)=gear4beta(28);
cv_FE(15,3)=gear4beta(29);
cv_FE(28,3)=gear4beta(30);
cv_FE(32,3)=gear4beta(31);
cv_FE(35,3)=gear4beta(32);
cv_FE(36,3)=gear4beta(33);
cv_FE(38,3)=gear4beta(34);
cv_FE(41,3)=gear4beta(35);
cv_FE(43,3)=gear4beta(36);
cv_FE(44,3)=gear4beta(37);
cv_FE(48,3)=gear4beta(38);
cv_FE(53,3)=gear4beta(39);
cv_FE(56,3)=gear4beta(40);
cv_FE(57,3)=gear4beta(41);
cv_FE(58,3)=gear4beta(42);
cv_FE(59,3)=gear4beta(43);
cv_FE(62,3)=gear4beta(44);
cv_FE(67,3)=gear4beta(45);
cv_FE(75,3)=gear4beta(46);
cv_FE(78,3)=gear4beta(47);
cv_FE(79,3)=gear4beta(48);
cv_FE(88,3)=gear4beta(49);
cv_FE(90,3)=gear4beta(50);
cv_FE(106,3)=gear4beta(51);
cv_FE(119,3)=gear4beta(52);
cv_FE(121,3)=gear4beta(53);
cv_FE(126,3)=gear4beta(54);
cv_FE(131,3)=gear4beta(55);
cv_FE(133,3)=gear4beta(56);
cv_FE(138,3)=gear4beta(57);
cv_FE(141,3)=gear4beta(58);
cv_FE(145,3)=gear4beta(59);
cv_FE(148,3)=gear4beta(60);
cv_FE(153,3)=gear4beta(61);
cv_FE(154,3)=gear4beta(62);
cv_FE(155,3)=gear4beta(63);
cv_FE(158,3)=gear4beta(64);
cv_FE(161,3)=gear4beta(65);
cv_FE(164,3)=gear4beta(66);
cv_FE(166,3)=gear4beta(67);
cv_FE(174,3)=gear4beta(68);
cv_FE(175,3)=gear4beta(69);
cv_FE(179,3)=gear4beta(70);
cv_FE(190,3)=gear4beta(71);
cv_FE(202,3)=gear4beta(72);
cv_FE(224,3)=gear4beta(73);
cv_FE(229,3)=gear4beta(74);
cv_FE(230,3)=gear4beta(75);
cv_FE(235,3)=gear4beta(76);
cv_FE(239,3)=gear4beta(77);
cv_FE(241,3)=gear4beta(78);
cv_FE(242,3)=gear4beta(79);
cv_FE(248,3)=gear4beta(80);
cv_FE(253,3)=gear4beta(81);
cv_FE(255,3)=gear4beta(82);
cv_FE(257,3)=gear4beta(83);
cv_FE(265,3)=gear4beta(84);
cv_FE(288,3)=gear4beta(85);
cv_FE(292,3)=gear4beta(86);
cv_FE(306,3)=gear4beta(87);
cv_FE(318,3)=gear4beta(88);
cv_FE(327,3)=gear4beta(89);
cv_FE(328,3)=gear4beta(90);
cv_FE(329,3)=gear4beta(91);
cv_FE(332,3)=gear4beta(92);
cv_FE(337,3)=gear4beta(93);
cv_FE(338,3)=gear4beta(94);
cv_FE(371,3)=gear4beta(95);
cv_FE(376,3)=gear4beta(96);
cv_FE(380,3)=gear4beta(97);
cv_FE(383,3)=gear4beta(98);
cv_FE(2,4)=gear5beta(66);
cv_FE(4,4)=gear5beta(67);
cv_FE(5,4)=gear5beta(68);
cv_FE(10,4)=gear5beta(69);
cv_FE(16,4)=gear5beta(70);
cv_FE(19,4)=gear5beta(71);
cv_FE(20,4)=gear5beta(72);
cv_FE(21,4)=gear5beta(73);
cv_FE(23,4)=gear5beta(74);
cv_FE(27,4)=gear5beta(75);
cv_FE(34,4)=gear5beta(76);
cv_FE(39,4)=gear5beta(77);
cv_FE(47,4)=gear5beta(78);
cv_FE(51,4)=gear5beta(79);
cv_FE(66,4)=gear5beta(80);
cv_FE(74,4)=gear5beta(81);
cv_FE(81,4)=gear5beta(82);
cv_FE(84,4)=gear5beta(83);
cv_FE(86,4)=gear5beta(84);
cv_FE(88,4)=gear5beta(85);
cv_FE(92,4)=gear5beta(86);
cv_FE(111,4)=gear5beta(87);
cv_FE(116,4)=gear5beta(88);
cv_FE(137,4)=gear5beta(89);
cv_FE(140,4)=gear5beta(90);
cv_FE(146,4)=gear5beta(91);
cv_FE(149,4)=gear5beta(92);
cv_FE(150,4)=gear5beta(93);
cv_FE(162,4)=gear5beta(94);
cv_FE(165,4)=gear5beta(95);
cv_FE(167,4)=gear5beta(96);
cv_FE(176,4)=gear5beta(97);
cv_FE(181,4)=gear5beta(98);
cv_FE(186,4)=gear5beta(99);
cv_FE(187,4)=gear5beta(100);
cv_FE(191,4)=gear5beta(101);
cv_FE(192,4)=gear5beta(102);
cv_FE(195,4)=gear5beta(103);
cv_FE(197,4)=gear5beta(104);
cv_FE(203,4)=gear5beta(105);
cv_FE(206,4)=gear5beta(106);
cv_FE(208,4)=gear5beta(107);
cv_FE(209,4)=gear5beta(108);
cv_FE(211,4)=gear5beta(109);
cv_FE(216,4)=gear5beta(110);
cv_FE(220,4)=gear5beta(111);
cv_FE(246,4)=gear5beta(112);
cv_FE(254,4)=gear5beta(113);
cv_FE(261,4)=gear5beta(114);
cv_FE(262,4)=gear5beta(115);
cv_FE(272,4)=gear5beta(116);
cv_FE(275,4)=gear5beta(117);
cv_FE(278,4)=gear5beta(118);
cv_FE(290,4)=gear5beta(119);
cv_FE(292,4)=gear5beta(120);
cv_FE(296,4)=gear5beta(121);
cv_FE(297,4)=gear5beta(122);
cv_FE(311,4)=gear5beta(123);
cv_FE(315,4)=gear5beta(124);
cv_FE(320,4)=gear5beta(125);
cv_FE(326,4)=gear5beta(126);
cv_FE(335,4)=gear5beta(127);
cv_FE(336,4)=gear5beta(128);
cv_FE(344,4)=gear5beta(129);
cv_FE(352,4)=gear5beta(130);
cv_FE(357,4)=gear5beta(131);


CP_FE(3,1)=CPgear2beta(66);
CP_FE(6,1)=CPgear2beta(67);
CP_FE(7,1)=CPgear2beta(69);
CP_FE(8,1)=CPgear2beta(70);
CP_FE(9,1)=CPgear2beta(71);
CP_FE(11,1)=CPgear2beta(72);
CP_FE(12,1)=CPgear2beta(73);
CP_FE(18,1)=CPgear2beta(74);
CP_FE(19,1)=CPgear2beta(75);
CP_FE(21,1)=CPgear2beta(76);
CP_FE(27,1)=CPgear2beta(77);
CP_FE(28,1)=CPgear2beta(78);
CP_FE(29,1)=CPgear2beta(79);
CP_FE(31,1)=CPgear2beta(80);
CP_FE(32,1)=CPgear2beta(81);
CP_FE(34,1)=CPgear2beta(82);
CP_FE(35,1)=CPgear2beta(83);
CP_FE(37,1)=CPgear2beta(84);
CP_FE(39,1)=CPgear2beta(85);
CP_FE(42,1)=CPgear2beta(86);
CP_FE(46,1)=CPgear2beta(87);
CP_FE(47,1)=CPgear2beta(88);
CP_FE(53,1)=CPgear2beta(89);
CP_FE(59,1)=CPgear2beta(90);
CP_FE(62,1)=CPgear2beta(91);
CP_FE(76,1)=CPgear2beta(92);
CP_FE(77,1)=CPgear2beta(93);
CP_FE(84,1)=CPgear2beta(94);
CP_FE(91,1)=CPgear2beta(96);
CP_FE(106,1)=CPgear2beta(97);
CP_FE(111,1)=CPgear2beta(98);
CP_FE(113,1)=CPgear2beta(99);
CP_FE(115,1)=CPgear2beta(100);
CP_FE(116,1)=CPgear2beta(101);
CP_FE(122,1)=CPgear2beta(102);
CP_FE(133,1)=CPgear2beta(103);
CP_FE(135,1)=CPgear2beta(104);
CP_FE(136,1)=CPgear2beta(105);
CP_FE(138,1)=CPgear2beta(106);
CP_FE(139,1)=CPgear2beta(107);
CP_FE(142,1)=CPgear2beta(108);
CP_FE(143,1)=CPgear2beta(109);
CP_FE(144,1)=CPgear2beta(110);
CP_FE(146,1)=CPgear2beta(111);
CP_FE(147,1)=CPgear2beta(112);
CP_FE(149,1)=CPgear2beta(113);
CP_FE(154,1)=CPgear2beta(114);
CP_FE(155,1)=CPgear2beta(115);
CP_FE(3,2)=CPgear3beta(66);
CP_FE(22,2)=CPgear3beta(67);
CP_FE(30,2)=CPgear3beta(68);
CP_FE(36,2)=CPgear3beta(69);
CP_FE(43,2)=CPgear3beta(70);
CP_FE(44,2)=CPgear3beta(71);
CP_FE(50,2)=CPgear3beta(72);
CP_FE(55,2)=CPgear3beta(73);
CP_FE(67,2)=CPgear3beta(74);
CP_FE(71,2)=CPgear3beta(75);
CP_FE(72,2)=CPgear3beta(76);
CP_FE(74,2)=CPgear3beta(77);
CP_FE(75,2)=CPgear3beta(78);
CP_FE(88,2)=CPgear3beta(79);
CP_FE(90,2)=CPgear3beta(80);
CP_FE(96,2)=CPgear3beta(81);
CP_FE(97,2)=CPgear3beta(82);
CP_FE(129,2)=CPgear3beta(83);
CP_FE(141,2)=CPgear3beta(84);
CP_FE(142,2)=CPgear3beta(85);
CP_FE(150,2)=CPgear3beta(86);
CP_FE(153,2)=CPgear3beta(87);
CP_FE(2,3)=CPgear4beta(28);
CP_FE(5,3)=CPgear4beta(29);
CP_FE(12,3)=CPgear4beta(30);
CP_FE(14,3)=CPgear4beta(31);
CP_FE(16,3)=CPgear4beta(32);
CP_FE(17,3)=CPgear4beta(33);
CP_FE(19,3)=CPgear4beta(34);
CP_FE(20,3)=CPgear4beta(35);
CP_FE(25,3)=CPgear4beta(36);
CP_FE(46,3)=CPgear4beta(37);
CP_FE(65,3)=CPgear4beta(38);
CP_FE(77,3)=CPgear4beta(39);
CP_FE(128,3)=CPgear4beta(40);
CP_FE(135,3)=CPgear4beta(41);
CP_FE(142,3)=CPgear4beta(42);
CP_FE(152,3)=CPgear4beta(43);
CP_FE(43,4)=CPgear5beta(66);
CP_FE(66,4)=CPgear5beta(67);
CP_FE(71,4)=CPgear5beta(68);
CP_FE(74,4)=CPgear5beta(69);
CP_FE(85,4)=CPgear5beta(70);
CP_FE(86,4)=CPgear5beta(71);
CP_FE(90,4)=CPgear5beta(72);
CP_FE(93,4)=CPgear5beta(73);
CP_FE(94,4)=CPgear5beta(74);
CP_FE(102,4)=CPgear5beta(75);
CP_FE(103,4)=CPgear5beta(76);
CP_FE(112,4)=CPgear5beta(77);
CP_FE(114,4)=CPgear5beta(78);
CP_FE(119,4)=CPgear5beta(79);
CP_FE(124,4)=CPgear5beta(80);
CP_FE(125,4)=CPgear5beta(81);
CP_FE(126,4)=CPgear5beta(82);
CP_FE(127,4)=CPgear5beta(83);




global beta;
beta=zeros(size(ms_beta,1),Y+1);
sim_beta=zeros(size(beta,1),Y+1,sim);

sim_stock1=zeros(length(bsaistock1)-1+Y+1,sim);
sim_stock2=zeros(length(bsaistock1)-1+Y+1,sim);
sim_stock3=zeros(length(bsaistock1)-1+Y+1,sim);
sim_harvest1=zeros(length(bsaicatch1)-1+Y+1,sim);
sim_harvest2=zeros(length(bsaicatch1)-1+Y+1,sim);
sim_harvest3=zeros(length(bsaicatch1)-1+Y+1,sim);
sim_aggrevenue=zeros(Y+1,sim);
sim_aggcost=zeros(Y+1,sim);
sim_aggprofit=zeros(Y+1,sim);

sim_q1=zeros(Y+1,sim);
sim_q2=zeros(Y+1,sim);
sim_q3=zeros(Y+1,sim);
sim_npv=zeros(sim,1);

sim_p1=zeros(Y+1,sim);
sim_p2=zeros(Y+1,sim);
sim_p3=zeros(Y+1,sim);
sim_p4=zeros(Y+1,sim);
sim_cvbeta=zeros(77,4,sim);
sim_cpbeta=zeros(77,4,sim);
sim_cvpoissonbeta=zeros(14,4,sim);
sim_cppoissonbeta=zeros(14,4,sim);

sim_cvcostcomp12=zeros(npx,gt,Y+1,sim);
sim_cvcostcomp13=zeros(npx,gt,Y+1,sim);
sim_cvcostcomp23=zeros(npx,gt,Y+1,sim);
sim_cpcostcomp12=zeros(npxcp,gt,Y+1,sim);
sim_cpcostcomp13=zeros(npxcp,gt,Y+1,sim);
sim_cpcostcomp23=zeros(npxcp,gt,Y+1,sim);




% just use the point estimates for the cost functions
cvbeta=[[gear2beta(1);0;gear2beta(2);0;0;gear2beta(3);0;gear2beta(4);gear2beta(5);gear2beta(6);gear2beta(7);0;gear2beta(8);0;0;gear2beta(9);0;gear2beta(10);gear2beta(11);gear2beta(12);0;0;0;0;0;0;0;0;0;gear2beta(13);0;0;gear2beta(14);0;gear2beta(15);gear2beta(16);gear2beta(17);0;0;0;0;0;0;0;0;0;0;0;0;0;gear2beta(18);0;gear2beta(19);gear2beta(20);gear2beta(21);0;0;0;0;gear2beta(22);gear2beta(23);gear2beta(24);gear2beta(25);gear2beta(26);gear2beta(27);gear2beta(46);gear2beta(47);0;gear2beta(48);0;0;gear2beta(49);0;gear2beta(50);gear2beta(51);gear2beta(52);gear2beta(53)] [gear3beta(1:65)';gear3beta(end-11:end)'] [gear4beta(1);0;gear4beta(2);0;0;gear4beta(3);0;gear4beta(4);gear4beta(5);gear4beta(6);gear4beta(7);0;gear4beta(8);0;0;gear4beta(9);0;gear4beta(10);gear4beta(11);gear4beta(12);0;0;0;0;0;0;0;0;0;gear4beta(13);0;0;gear4beta(14);0;gear4beta(15);gear4beta(16);gear4beta(17);0;0;0;0;0;0;0;0;0;0;0;0;0;gear4beta(18);0;gear4beta(19);gear4beta(20);gear4beta(21);0;0;0;0;gear4beta(22);gear4beta(23);gear4beta(24);gear4beta(25);gear4beta(26);gear4beta(27);gear4beta(99);gear4beta(100);0;gear4beta(101);0;0;gear4beta(102);0;gear4beta(103);gear4beta(104);gear4beta(105);gear4beta(106)] [gear5beta(1:65)';gear5beta(end-11:end)']];  
cvpoissonbeta=[gear2poissonbeta gear3poissonbeta gear4poissonbeta gear5poissonbeta];
cpbeta=[[CPgear2beta(1:65)';CPgear2beta(end-11:end)'] [CPgear3beta(1:65)';CPgear3beta(end-11:end)'] [CPgear4beta(1);0;CPgear4beta(2);0;0;CPgear4beta(3);0;CPgear4beta(4);CPgear4beta(5);CPgear4beta(6);CPgear4beta(7);0;CPgear4beta(8);0;0;CPgear4beta(9);0;CPgear4beta(10);CPgear4beta(11);CPgear4beta(12);0;0;0;0;0;0;0;0;0;CPgear4beta(13);0;0;CPgear4beta(14);0;CPgear4beta(15);CPgear4beta(16);CPgear4beta(17);0;0;0;0;0;0;0;0;0;0;0;0;0;CPgear4beta(18);0;CPgear4beta(19);CPgear4beta(20);CPgear4beta(21);0;0;0;0;CPgear4beta(22);CPgear4beta(23);CPgear4beta(24);CPgear4beta(25);CPgear4beta(26);CPgear4beta(27);CPgear4beta(44);CPgear4beta(45);0;CPgear4beta(46);0;0;CPgear4beta(47);0;CPgear4beta(48);CPgear4beta(49);CPgear4beta(50);CPgear4beta(51)] [CPgear5beta(1:65)';CPgear5beta(end-11:end)']];
cppoissonbeta=[CPgear2poissonbeta CPgear3poissonbeta CPgear4poissonbeta CPgear5poissonbeta];





for s=1:sim 
    
    % multispecies
%     for i=1:Y
%         beta(:,i)=mvnrnd(ms_beta,ms_V)';
%     end
%     beta(:,Y+1)=mean(beta,2);
    
    %         single species
    %         beta(1:2,1)  = ss_beta1(1:2,1);
    %         beta(6:7,1)  = ss_beta2(1:2,1);
    %         beta(11:12,1)= ss_beta3(1:2,1);
    %         beta(1:2,1)  = mvnrnd(ss_beta1(1:2,1),ss_V1(1:2,1:2))';
    %         beta(6:7,1)  = mvnrnd(ss_beta2(1:2,1),ss_V2(1:2,1:2)';
    %         beta(11:12,1)= mvnrnd(q1ss_beta3(1:2,1),ss_V3(1:2,1:2)';
    
%     sample from the cost function, rather than going with the 
%     point estimates 
%     cvbeta=[mvnrnd(gear2beta',gear2V)' mvnrnd(gear3beta',gear3V)' mvnrnd(gear4beta',gear4V)' mvnrnd(gear5beta',gear5V)'];
%     cvpoissonbeta=[mvnrnd(gear2poissonbeta',gear2poissonV)' mvnrnd(gear3poissonbeta',gear3poissonV)' mvnrnd(gear4poissonbeta',gear4poissonV)' mvnrnd(gear5poissonbeta',gear5poissonV)'];
%     cpbeta=[mvnrnd(CPgear2beta',CPgear2V)' mvnrnd(CPgear3beta',CPgear3V)' mvnrnd(CPgear4beta',CPgear4V)' mvnrnd(CPgear5beta',CPgear5V)'];
%     cppoissonbeta=[mvnrnd(CPgear2poissonbeta',CPgear2poissonV)' mvnrnd(CPgear3poissonbeta',CPgear3poissonV)' mvnrnd(CPgear4poissonbeta',CPgear4poissonV)' mvnrnd(CPgear5poissonbeta',CPgear5poissonV)'];

    
    
%     global p1 p2 p3;
%     p1=zeros(Y+1,1);
%     p2=zeros(Y+1,1);
%     p3=zeros(Y+1,1);
%     
%     this uses the VAR model to determine prices 
%     the prices are generally pretty low, and don't have any demand
%     response.  
%     for i=1:Y
%         p1(i,1)=pr_bsaiaveprice1(i,1) + pr_bsaiaveprice1_SE(i,1).*randn(1,1);
%         while p1(i,1)<=0
%             p1(i,1)=pr_bsaiaveprice1(i,1) + pr_bsaiaveprice1_SE(i,1).*randn(1,1);
%         end
%         p2(i,1)=pr_bsaiaveprice2(i,1) + pr_bsaiaveprice2_SE(i,1).*randn(1,1);
%         while p2(i,1)<=0
%             p2(i,1)=pr_bsaiaveprice2(i,1) + pr_bsaiaveprice2_SE(i,1).*randn(1,1);
%         end
%         p3(i,1)=pr_bsaiaveprice3(i,1) + pr_bsaiaveprice3_SE(i,1).*randn(1,1);
%         while p3(i,1)<=0
%             p3(i,1)=pr_bsaiaveprice3(i,1) + pr_bsaiaveprice3_SE(i,1).*randn(1,1);
% %             p3(i,1)=.165*2204.62262 + pr_bsaiaveprice3_SE(i,1).*randn(1,1);
%         end
%     end
%      
%     p1(Y+1,1)=mean(p1);
%     p2(Y+1,1)=mean(p2);
%     p3(Y+1,1)=mean(p3);



%     this uses the inverse demand model from stata
%     pricebetahat(:,1)=mvnrnd(pricebeta,priceV);
%     while pricebetahat(4,1)>0 || pricebetahat(9,1)>0 || pricebetahat(14,1)>0
%         pricebetahat(:,1)=mvnrnd(pricebeta,priceV);
%     end
%     pricebeta1(:,1)=pricebetahat(1:5,1);
%     pricebeta2(:,1)=pricebetahat(6:10,1);
%     pricebeta3(:,1)=pricebetahat(11:15,1);

    
    

    
    
    % possible algorithms
    % active-set
    % interior-point
    % levenberg-marquardt
    % sqp
    % trust-region-dogleg
    % trust-region-reflective
    
    
    % options = optimset('Display','on','Algorithm', 'interior-point', 'TolX', 1e-25, 'TolCon', 1e-20, 'TolFun', 1e-20);
    % options = optimset('Display','iter','TolX', 1e-25, 'TolCon', 1e-20, 'TolFun', 1e-20);
%   this one  options = optimset('Display','iter','Algorithm','interior-point','FunValCheck','on','MaxFunEvals',1e10,'Maxiter',1e10,'UseParallel','always','PlotFcns',@optimplotx);
%     options = optimset('Display','iter','Algorithm','interior-point','FunValCheck','on','MaxFunEvals',1e10,'Maxiter',1e10,'UseParallel','always');

% % don't optimize over arth
%     x0=[(168780/bsaistock2(end))*ones(Y-1,1); (832000/bsaistock3(end))*ones(Y-1,1) ];
%     lb=zeros(2*Y-2,1);
%     ub=.75*ones(2*-2,1);
%     [q,npv]=fmincon(@npvfun_noarth,x0,[],[],[],[],lb,ub,[],options);
% %     [q,npv]=ktrlink(@npvfun_noarth,x0,[],[],[],[],lb,ub,[],[]);
    

% include constraints such that q=[0,1]
%     x0=[15000*ones(Y-1,1); 168780*ones(Y-1,1); 832000*ones(Y-1,1) ];
%     x0=[(15000/bsaistock1(end))*ones(Y-1,1); (168780/bsaistock2(end))*ones(Y-1,1); (832000/bsaistock3(end))*ones(Y-1,1) ];
%     lb=zeros(3*Y-3,1);
%     ub=.75*ones(3*Y-3,1);
%  this one   [q,npv]=fmincon(@npvfun,x0,[],[],[],[],lb,ub,[],options);
%     [q,npv]=ktrlink(@npvfun,x0,[],[],[],[],lb,ub,[],options);
    
%     [q,npv]=fminunc(@npvfun,x0,options);
    % [q,npv]=fminsearch(@npvfun,x0,options);
%     [q,npv]=ktrlink(@npvfun,x0);
    
% this uses the short optimization routine, and does the whole thing
% over again if it doesn't converge.  
    exitflag=0;
    while exitflag<=0
        for i=1:Y
            beta(:,i)=mvnrnd(ms_beta,ms_V)';
        end
        beta(:,Y+1)=mean(beta,2);
        pricebetahat(:,1)=mvnrnd(pricebeta,priceV);
        while pricebetahat(4,1)>0 || pricebetahat(9,1)>0 || pricebetahat(14,1)>0
            pricebetahat(:,1)=mvnrnd(pricebeta,priceV);
        end
        pricebeta1(:,1)=pricebetahat(1:5,1);
        pricebeta2(:,1)=pricebetahat(6:10,1);
        pricebeta3(:,1)=pricebetahat(11:15,1);
        options = optimset('Display','iter','Algorithm','interior-point','FunValCheck','on','MaxFunEvals',1e4,'Maxiter',1e3,'UseParallel','always','PlotFcns',@optimplotx);
        x0=[(15000/bsaistock1(end))*ones(Y-1,1); (168780/bsaistock2(end))*ones(Y-1,1); (832000/bsaistock3(end))*ones(Y-1,1) ];
        lb=zeros(3*Y-3,1);
        ub=.75*ones(3*Y-3,1);
        [q,npv,exitflag]=fmincon(@npvfun_fe,x0,[],[],[],[],lb,ub,[],options);
        sprintf('%s','ITERATION ended with exitflag = ',int2str(exitflag))
    end
    sprintf('%s','SIMULATION ended with exitflag = ',int2str(exitflag))

    
    -npv
    
    global q1 q2 q3;
    global p1 p2 p3 p4;
    global Yyear;
    global x1 x2 x3;
    % global beta;
    global aggrevenue;
    global aggcost;
    global aggprofit;
    global toth1 toth2 toth3;
    global cvcostcomp12 cvcostcomp13 cvcostcomp23 cpcostcomp12 cpcostcomp13 cpcostcomp23 

    [q1 q2 q3 [q1 q2 q3].*[x1 x2 x3] toth1 toth2 toth3]
    sim_q1(:,s)=q1;
    sim_q2(:,s)=q2;
    sim_q3(:,s)=q3;
    sim_npv(s,1)=-npv;

    stock1=zeros(length(bsaistock1)-1+Y+1,1);
    stock2=zeros(length(bsaistock2)-1+Y+1,1);
    stock3=zeros(length(bsaistock3)-1+Y+1,1);
    
    harvest1=zeros(length(bsaicatch1)-1+Y+1,1);
    harvest2=zeros(length(bsaicatch1)-1+Y+1,1);
    harvest3=zeros(length(bsaicatch1)-1+Y+1,1);
    
    stock1(:,1)=[bsaistock1(1:end-1);x1(:,1)];
    stock2(:,1)=[bsaistock2(1:end-1);x2(:,1)];
    stock3(:,1)=[bsaistock3(1:end-1);x3(:,1)];
    harvest1(:,1)=[bsaicatch1(1:end-1);toth1(:,1)];
    harvest2(:,1)=[bsaicatch2(1:end-1);toth2(:,1)];
    harvest3(:,1)=[bsaicatch3(1:end-1);toth3(:,1)];
    
    
    sim_stock1(:,s)=[bsaistock1(1:end-1);x1(:,1)];
    sim_stock2(:,s)=[bsaistock2(1:end-1);x2(:,1)];
    sim_stock3(:,s)=[bsaistock3(1:end-1);x3(:,1)];
    sim_harvest1(:,s)=[bsaicatch1(1:end-1);toth1(:,1)];
    sim_harvest2(:,s)=[bsaicatch2(1:end-1);toth2(:,1)];
    sim_harvest3(:,s)=[bsaicatch3(1:end-1);toth3(:,1)];
    
    sim_aggprofit(:,s)=aggprofit(:,1);
    sim_aggrevenue(:,s)=aggrevenue(:,1);
    sim_aggcost(:,s)=aggcost(:,1);
    
    sim_beta(:,:,s)=beta;
    sim_p1(:,s)=p1;
    sim_p2(:,s)=p2;
    sim_p3(:,s)=p3;
    sim_p4(:,s)=p4;
    sim_cvbeta(:,:,s)=cvbeta;
    sim_cpbeta(:,:,s)=cpbeta;
    sim_cvpoissonbeta(:,:,s)=cvpoissonbeta;
    sim_cppoissonbeta(:,:,s)=cppoissonbeta;
    
    sim_cvcostcomp12(:,:,:,s)=cvcostcomp12;
    sim_cvcostcomp13(:,:,:,s)=cvcostcomp13;
    sim_cvcostcomp23(:,:,:,s)=cvcostcomp23;
    sim_cpcostcomp12(:,:,:,s)=cpcostcomp12;
    sim_cpcostcomp13(:,:,:,s)=cpcostcomp13;
    sim_cpcostcomp23(:,:,:,s)=cpcostcomp23;

    sprintf('%s','Total Cost Savings for CV arth/cod, arth/plck, and cod/plck')
    [sum(sum(sum(cvcostcomp12))) sum(sum(sum(cvcostcomp13))) sum(sum(sum(cvcostcomp23)))]
    sprintf('%s','Overall Total CV Cost Savings')
    sum(sum(sum(cvcostcomp12)))+sum(sum(sum(cvcostcomp13)))+sum(sum(sum(cvcostcomp23)))
    sprintf('%s','Total Cost Savings for CP arth/cod, arth/plck, and cod/plck')
    [sum(sum(sum(cpcostcomp12))) sum(sum(sum(cpcostcomp13))) sum(sum(sum(cpcostcomp23)))]
    sprintf('%s','Overall Total CP Cost Savings')
    sum(sum(sum(cpcostcomp12)))+sum(sum(sum(cpcostcomp13)))+sum(sum(sum(cpcostcomp23)))
    
    
    
    s
    if s==1 || s==25 || s==50 || s==75 || s==90 || s==95
        simyear=int2str(i);
        totsim=int2str(sim);
        simnum=int2str(s);
        sendmail('steve.kasperski@gmail.com', [simyear,'years',totsim,'simfc',suffix,' is on simulation number ',simnum], [simyear,'years',totsim,'simfc',suffix,' is on simulation number ',simnum]);
    end




end

% the cost comp is not discounted - so do that here.
for i=1:size(sim_cvcostcomp12,3)
    sim_cvcostcomp12(:,:,i,:)=sim_cvcostcomp12(:,:,i,:)./((1+theta)^(i-1));
    sim_cvcostcomp13(:,:,i,:)=sim_cvcostcomp13(:,:,i,:)./((1+theta)^(i-1));
    sim_cvcostcomp23(:,:,i,:)=sim_cvcostcomp23(:,:,i,:)./((1+theta)^(i-1));
    sim_cpcostcomp12(:,:,i,:)=sim_cpcostcomp12(:,:,i,:)./((1+theta)^(i-1));
    sim_cpcostcomp13(:,:,i,:)=sim_cpcostcomp13(:,:,i,:)./((1+theta)^(i-1));
    sim_cpcostcomp23(:,:,i,:)=sim_cpcostcomp23(:,:,i,:)./((1+theta)^(i-1));
end

sumcvcostcomp12=zeros(sim,1);
sumcvcostcomp13=zeros(sim,1);
sumcvcostcomp23=zeros(sim,1);
sumcpcostcomp12=zeros(sim,1);
sumcpcostcomp13=zeros(sim,1);
sumcpcostcomp23=zeros(sim,1);

crapcv12=sum(sum(sum(sim_cvcostcomp12,3),2),1);
crapcv13=sum(sum(sum(sim_cvcostcomp13,3),2),1);
crapcv23=sum(sum(sum(sim_cvcostcomp23,3),2),1);
crapcp12=sum(sum(sum(sim_cpcostcomp12,3),2),1);
crapcp13=sum(sum(sum(sim_cpcostcomp13,3),2),1);
crapcp23=sum(sum(sum(sim_cpcostcomp23,3),2),1);

for i=1:sim
    sumcvcostcomp12(i,1)=crapcv12(1,1,1,i);
    sumcvcostcomp13(i,1)=crapcv13(1,1,1,i);
    sumcvcostcomp23(i,1)=crapcv23(1,1,1,i);
    sumcpcostcomp12(i,1)=crapcp12(1,1,1,i);
    sumcpcostcomp13(i,1)=crapcp13(1,1,1,i);
    sumcpcostcomp23(i,1)=crapcp23(1,1,1,i);
end
% [sumcvcostcomp12 sumcvcostcomp13 sumcvcostcomp23 sumcpcostcomp12 sumcpcostcomp13 sumcpcostcomp23]
totalcostcomp=sumcvcostcomp12+sumcvcostcomp13+sumcvcostcomp23+sumcpcostcomp12+sumcpcostcomp13+sumcpcostcomp23;
sprintf('%s','Median Total Cost Savings from Cost Complimentarities of all simulations (should be negative)')
median(totalcostcomp)

simtime=toc;

graphyear=[stock_year(1:end-1);Yyear];

i=int2str(Y);
j=int2str(sim);

scrsz = get(0,'ScreenSize');
% figure 1
fig1=figure('Position', scrsz);
subplot(3,1,1)
plot(Yyear, median(sim_stock1(length(bsaistock1):end,:),2),'b','LineStyle','-','LineWidth',3)
hold on
plot(Yyear, median(sim_harvest1(length(bsaistock1):end,:),2),'b','LineStyle','--','LineWidth',3)
plot(Yyear, prctile(sim_stock1(length(bsaistock1):end,:),25,2),'b','LineStyle','-','LineWidth',1)
plot(Yyear, prctile(sim_stock1(length(bsaistock1):end,:),75,2),'b','LineStyle','-','LineWidth',1)
plot(Yyear, prctile(sim_harvest1(length(bsaistock1):end,:),25,2),'b','LineStyle','--','LineWidth',1)
plot(Yyear, prctile(sim_harvest1(length(bsaistock1):end,:),75,2),'b','LineStyle','--','LineWidth',1)
hold off
legend('Stock','Harvest','Location','NorthWest', 'Orientation','vertical')
title('Arrowtooth')
subplot(3,1,2)
plot(Yyear, median(sim_stock2(length(bsaistock1):end,:),2),'r','LineStyle','-','LineWidth',3)
hold on
plot(Yyear, median(sim_harvest2(length(bsaistock2):end,:),2),'r','LineStyle','--','LineWidth',3)
plot(Yyear, prctile(sim_stock2(length(bsaistock2):end,:),25,2),'r','LineStyle','-','LineWidth',1)
plot(Yyear, prctile(sim_stock2(length(bsaistock2):end,:),75,2),'r','LineStyle','-','LineWidth',1)
plot(Yyear, prctile(sim_harvest2(length(bsaistock2):end,:),25,2),'r','LineStyle','--','LineWidth',1)
plot(Yyear, prctile(sim_harvest2(length(bsaistock2):end,:),75,2),'r','LineStyle','--','LineWidth',1)
hold off
legend('Stock','Harvest','Location','NorthWest', 'Orientation','vertical')
title('Cod')
subplot(3,1,3)
plot(Yyear, median(sim_stock3(length(bsaistock3):end,:),2),'k','LineStyle','-','LineWidth',3)
hold on
plot(Yyear, median(sim_harvest3(length(bsaistock3):end,:),2),'k','LineStyle','--','LineWidth',3)
plot(Yyear, prctile(sim_stock3(length(bsaistock3):end,:),25,2),'k','LineStyle','-','LineWidth',1)
plot(Yyear, prctile(sim_stock3(length(bsaistock3):end,:),75,2),'k','LineStyle','-','LineWidth',1)
plot(Yyear, prctile(sim_harvest3(length(bsaistock3):end,:),25,2),'k','LineStyle','--','LineWidth',1)
plot(Yyear, prctile(sim_harvest3(length(bsaistock3):end,:),75,2),'k','LineStyle','--','LineWidth',1)
hold off
legend('Stock','Harvest','Location','NorthWest', 'Orientation','vertical')
title('Pollock')
saveas(fig1,[basepath,i,'years',j,'simfc',suffix,'_fig1.png'])

% figure 2
fig2=figure('Position', scrsz)
subplot(3,1,1)
plot(graphyear, median(sim_stock1,2)./1e3,'b','LineStyle','-','LineWidth',3)
hold on
plot(graphyear, median(sim_harvest1,2)./1e3,'b','LineStyle','--','LineWidth',3)
plot(graphyear, prctile(sim_stock1,25,2)./1e3,'b','LineStyle','-','LineWidth',1)
plot(graphyear, prctile(sim_stock1,75,2)./1e3,'b','LineStyle','-','LineWidth',1)
plot(graphyear, prctile(sim_harvest1,25,2)./1e3,'b','LineStyle','--','LineWidth',1)
plot(graphyear, prctile(sim_harvest1,75,2)./1e3,'b','LineStyle','--','LineWidth',1)
vline(stock_year(end),'g')
hold off
legend('Stock','Harvest','Location','NorthWest', 'Orientation','vertical')
title('Arrowtooth')
ylabel('Thousands of Tons')
xlabel('Year')
subplot(3,1,2)
plot(graphyear, median(sim_stock2,2)./1e3,'r','LineStyle','-','LineWidth',3)
hold on
plot(graphyear, median(sim_harvest2,2)./1e3,'r','LineStyle','--','LineWidth',3)
plot(graphyear, prctile(sim_stock2,25,2)./1e3,'r','LineStyle','-','LineWidth',1)
plot(graphyear, prctile(sim_stock2,75,2)./1e3,'r','LineStyle','-','LineWidth',1)
plot(graphyear, prctile(sim_harvest2,25,2)./1e3,'r','LineStyle','--','LineWidth',1)
plot(graphyear, prctile(sim_harvest2,75,2)./1e3,'r','LineStyle','--','LineWidth',1)
vline(stock_year(end),'g')
hold off
legend('Stock','Harvest','Location','NorthWest', 'Orientation','vertical')
title('Cod')
ylabel('Thousands of Tons')
xlabel('Year')
subplot(3,1,3)
plot(graphyear, median(sim_stock3,2)./1e3,'k','LineStyle','-','LineWidth',3)
hold on
plot(graphyear, median(sim_harvest3,2)./1e3,'k','LineStyle','--','LineWidth',3)
plot(graphyear, prctile(sim_stock3,25,2)./1e3,'k','LineStyle','-','LineWidth',1)
plot(graphyear, prctile(sim_stock3,75,2)./1e3,'k','LineStyle','-','LineWidth',1)
plot(graphyear, prctile(sim_harvest3,25,2)./1e3,'k','LineStyle','--','LineWidth',1)
plot(graphyear, prctile(sim_harvest3,75,2)./1e3,'k','LineStyle','--','LineWidth',1)
vline(stock_year(end),'g')
hold off
legend('Stock','Harvest','Location','NorthWest', 'Orientation','vertical')
title('Pollock')
ylabel('Thousands of Tons')
xlabel('Year')
saveas(fig2,[basepath,i,'years',j,'simfc',suffix,'_fig2.png'])




% figure 3
fig3=figure('Position', scrsz)
plot(Yyear, median(sim_aggprofit,2),'k','LineStyle','-','LineWidth',3)
hold on
plot(Yyear, median(sim_aggrevenue,2),'r','LineStyle','-.','LineWidth',3)
plot(Yyear, median(sim_aggcost,2),'b','LineStyle','--','LineWidth',3)
plot(Yyear, prctile(sim_aggprofit,25,2)','k','LineStyle','-','LineWidth',1)
plot(Yyear, prctile(sim_aggprofit,75,2)','k','LineStyle','-','LineWidth',1)
plot(Yyear, prctile(sim_aggrevenue,25,2),'r','LineStyle','-.','LineWidth',1)
plot(Yyear, prctile(sim_aggrevenue,75,2),'r','LineStyle','-.','LineWidth',1)
plot(Yyear, prctile(sim_aggcost,25,2),'b','LineStyle','--','LineWidth',1)
plot(Yyear, prctile(sim_aggcost,75,2),'b','LineStyle','--','LineWidth',1)
hold off
legend('Profit','Revenue','Cost','Location','NorthWest', 'Orientation','vertical')
title('Profit')
saveas(fig3,[basepath,i,'years',j,'simfc',suffix,'_fig3.png'])

% figure 4
fig4=figure('Position', scrsz)
plot(Yyear, median(sim_p1,2),'b','LineStyle','-','LineWidth',3)
hold on
plot(Yyear, median(sim_p2,2),'r','LineStyle','-','LineWidth',3)
plot(Yyear, median(sim_p3,2),'k','LineStyle','-','LineWidth',3)
plot(Yyear, median(sim_p4,2),'g','LineStyle','-','LineWidth',3)
plot(Yyear, prctile(sim_p1,25,2)','b','LineStyle','--','LineWidth',1)
plot(Yyear, prctile(sim_p1,75,2)','b','LineStyle','--','LineWidth',1)
plot(Yyear, prctile(sim_p2,25,2),'r','LineStyle','--','LineWidth',1)
plot(Yyear, prctile(sim_p2,75,2),'r','LineStyle','--','LineWidth',1)
plot(Yyear, prctile(sim_p3,25,2),'k','LineStyle','--','LineWidth',1)
plot(Yyear, prctile(sim_p3,75,2),'k','LineStyle','--','LineWidth',1)
hold off
legend('Price of Arrowtooth','Price of Cod','Price of Pollock','Wage Price','Location','NorthWest', 'Orientation','vertical')
title('Prices')
saveas(fig4,[basepath,i,'years',j,'simfc',suffix,'_fig4.png'])




global cvrevenuemat cvannualrevenuemat cvannualrevenue;
global cvcostmat cvannualcostmat cvannualcost;
global cvprofitmat;
global cprevenuemat cpannualrevenuemat cpannualrevenue;
global cpcostmat cpannualcostmat cpannualcost;
global cpprofitmat;
global cvX cpX;
global cvh1 cvh2 cvh3 cph1 cph2 cph3;
global cvq1 cvq2 cvq3 cpq1 cpq2 cpq3;
global cvtripshat cpweekshat;


% clear
% clc

% % don't optimize over arth
% suffix='_noarth';

close(fig1)
close(fig2)
close(fig3)
close(fig4)


eval(sprintf('%s','save ',i,'years',j,'simfc',suffix,'.mat'));

% eval(sprintf('%s','load ',i,'years',j,'simfc',suffix,'.mat'));

% save 10years20simfc_noarth
% i=int2str(Y);
% j=int2str(sim);
% eval(sprintf('%s','save ',i,'years',j,'simfc_noarth.mat'));



    
% Determine whether or not to send the whole mat file and figures, or just
% the smaller series of csv files and m files and figures
model = sprintf('%s',i,'years',j,'simfc',suffix);
matfile=fullfile('D:','ESBFM','Data','Individual years','Normalized Quadratic','crewservices','FE',[model,'.mat']);
npvmodel_file=fullfile('D:','ESBFM','Data','Individual years','Normalized Quadratic','crewservices','FE',['npvmodel',suffix,'.m']);
npvfun_file=fullfile('D:','ESBFM','Data','Individual years','Normalized Quadratic','crewservices','FE',['npvfun',suffix,'.m']);
zipfile=fullfile('D:','ESBFM','Data','Individual years','Normalized Quadratic','crewservices','FE',[model,'.zip']);
zip(zipfile,{matfile,npvmodel_file,npvfun_file,[basepath,i,'years',j,'simfc',suffix,'_fig1.png'],[basepath,i,'years',j,'simfc',suffix,'_fig2.png'],[basepath,i,'years',j,'simfc',suffix,'_fig3.png'],[basepath,i,'years',j,'simfc',suffix,'_fig4.png']});

sizezipfile=dir(zipfile);
if sizezipfile.bytes>25e6
    csvwrite([basepath,model,'_npv.csv'], sim_npv)
    csvwrite([basepath,model,'_stockandharvest.csv'], [sim_stock1 sim_stock2 sim_stock3 sim_harvest1 sim_harvest2 sim_harvest3])
    csvwrite([basepath,model,'_qandprofits.csv'], [sim_q1 sim_q2 sim_q3 sim_aggprofit sim_aggrevenue sim_aggcost])
    zipfile_small=fullfile('D:','ESBFM','Data','Individual years','Normalized Quadratic','crewservices',[model,'_small.zip']);
    zip(zipfile_small,{[basepath,model,'_npv.csv'],[basepath,model,'_stockandharvest.csv'],[basepath,model,'_qandprofits.csv'],npvmodel_file,npvfun_file,[basepath,i,'years',j,'simfc',suffix,'_fig1.png'],[basepath,i,'years',j,'simfc',suffix,'_fig2.png'],[basepath,i,'years',j,'simfc',suffix,'_fig3.png'],[basepath,i,'years',j,'simfc',suffix,'_fig4.png']});
    sizezipfile_small=dir(zipfile_small);
    if sizezipfile_small.bytes>25e6
        zipfile_verysmall=fullfile('D:','ESBFM','Data','Individual years','Normalized Quadratic','crewservices',[model,'_verysmall.zip']);
        zip(zipfile_verysmall,{[basepath,model,'_npv.csv'],npvmodel_file,npvfun_file,[basepath,i,'years',j,'simfc',suffix,'_fig1.png'],[basepath,i,'years',j,'simfc',suffix,'_fig2.png'],[basepath,i,'years',j,'simfc',suffix,'_fig3.png'],[basepath,i,'years',j,'simfc',suffix,'_fig4.png']});
        sendmail('steve.kasperski@gmail.com', [model,'_verysmall'], 'Small Model still too big, only npv CSV file, m files, and figures are attached',zipfile_verysmall);
    else
        sendmail('steve.kasperski@gmail.com', [model,'_small'], 'Model too big, CSV files, m files, and figures are attached',zipfile_small);
    end
else
    sendmail('steve.kasperski@gmail.com', model, 'MAT file, m files, and figures are attached',zipfile);
end
    




format short
sprintf('%s','Total time in seconds was ')
simtime
sprintf('%s','Total time in minutes was ')
simtime/60
sprintf('%s','Total time in hours was ')
simtime/3600
sprintf('%s','Minutes per simulation ') 
simtime/60/sim

