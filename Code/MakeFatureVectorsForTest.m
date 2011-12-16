function [ WPTFeaureVectors] = MakeFatureVectorsForTest(WPTContours,TypeOfFature,TestSize)
%Features:
% 1 - Angular
% 2 - Shape Context

NumOfWPTS=size(WPTContours,1);
WPTFeaureVectors = cell(NumOfWPTS,2);
myfilter = fspecial('gaussian',[5 5], 0.5);

if (TypeOfFature == 1)
     for i=1:min(NumOfWPTS,TestSize)
         NextCont = WPTContours{i,1};
         FaturesValues = NewMultiResMSC(NextCont,2);
         WPTFeaureVectors {i,1} = FaturesValues;
      %   WPTFeaureVectors {i,2} = WPTContours {i,2} ;
     end
end

r_inner=1/8;
r_outer=2;

mean_dist_global=[]; % use [] to estimate scale from the data
nbins_theta=12;
nbins_r=5;


if (TypeOfFature == 2)
     for i=1:min(NumOfWPTS,TestSize)
         NextCont = WPTContours{i,1};
         nsamp=size(NextCont,1);
         out_vec=zeros(1,nsamp); 
         [FaturesValues,mean_dist_1]=sc_compute((NextCont)',zeros(1,nsamp),mean_dist_global,nbins_theta,nbins_r,r_inner,r_outer,out_vec);
         WPTFeaureVectors {i,1} = FaturesValues ;
%         WPTFeaureVectors {i,2} = WPTContours {i,2} ;
     end
end


nwin_x =9;
nwin_y = 3;
Bins = 12;


if (TypeOfFature == 3)
         for i=1:min(NumOfWPTS,TestSize)
                NextImg = WPTContours{i,1};
                NextImg = bwdist(NextImg);
                NextImg = imfilter(NextImg, myfilter,'replicate');
                WPTFeaureVectors {i,1} =  HOG(NextImg,nwin_x,nwin_y,Bins);
                WPTFeaureVectors {i,2} = WPTContours {i,2} ;
        end
end


if (TypeOfFature == 4)
         for i=1:min(NumOfWPTS,TestSize)
                NextImg = WPTContours{i,1};
                NextImg = NormalizeImage(NextImg);
                WPTFeaureVectors {i,1} =  HorizSlideFatures(NextImg);
                WPTFeaureVectors {i,2} = WPTContours {i,2} ;
        end
end

end
