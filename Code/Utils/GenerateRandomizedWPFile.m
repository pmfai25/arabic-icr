function [ output_args ] = GenerateRandomizedWPFile ( inputFilepath,outputFilePath,numWords )
%GENERATERANDOMIZEDWPFILE Summary of this function goes here
%   GenerateRandomizedWPFile('C:\OCRData\TestLegs.txt','C:\OCRData\TestLegs1000rand.txt',1000 )

fid = fopen(inputFilepath);
Wd= fgetl(fid);
cell={};
while (Wd ~= -1)
    cell = [cell;Wd];
    Wd= fgetl(fid);
end
fclose(fid);

UniqueCellArray = unique(cell);
numAllWords = size(UniqueCellArray,1);
RandStream.setDefaultStream(RandStream('mt19937ar','seed',sum(100*clock)));
SelectedIndexes = zeros(numAllWords,1,'int8');
for i=1:numWords
    index = randi(numAllWords,1,1);
    while (SelectedIndexes(index)==1)
       index = randi(numAllWords);
    end
    SelectedIndexes(index)=1;
end

edit(outputFilePath);
fid = fopen(outputFilePath,'wt');

Selected = find(SelectedIndexes);
for i=1:numWords
    word = UniqueCellArray{Selected(i)};
    fprintf(fid,'%s\n',word);
end
fclose (fid);
end

