function entrain_FFTplot
%This script will take FFT data and make frequency plots which reflect the
%average amplitude of at a speicifc freuqecy across multiple conditions.
%Make sure you have run "entrain_entrainment" before running this script.
%
%
%
%

clc
%set up the parent directory of the EntrainmentAnalysis folder
if ispc == 1
    parentDir = cell2mat(inputdlg('Enter the directory of the EntrainmentAnalysis folder'));
    addpath(parentDir)
else
    waitfor(msgbox('Press OK to select the location of the EntrainmentAnalysis folder'));
    parentDir = uigetdir;
end

%location of the FFT files
datadir = fullfile(parentDir,'data','FFT');

% list of participant files
ids = dir(datadir);
ids = {ids.name};
ids = ids(~ismember(ids,{'.','..','.DS_Store','._.DS_Store'}));

for id = 1:length(ids)
    
    %load the data stucture
    load(fullfile(datadir,ids{id}))
    
    dataOG = data;
    
    %only ask to rename conditions for the first partipant
    if id == 1
        %ask user if they would like to rename the conditions
        rename = inputdlg(num2str(data.trialOrder),...
            'Would you like to rename the conditions? (yes/no)',...
            [1 100]);
        %if you would like to rename the conditions loop through the TrialOrder
        %and rename each column
        if strcmp(rename,'yes')
            
            for ii = 1:size(data.trialOrder,2)
                conditionName = inputdlg(num2str(dataOG.trialOrder(ii)),...
                    'What is the name of this condition?',...
                    [1 30]);
                conditionName = cell2mat(conditionName);
                trialOrderNew{ii} = conditionName;
            end
            data.trialOrder = trialOrderNew;
            
            %save table with old names and corresponding new names used for
            %every participant
            matchNames = table((dataOG.trialOrder)',trialOrderNew',...
                'VariableNames',{'Original' 'New'});
            
        else
        end
        
        %if its not the first particpant then save the names of the conditions
    else
        clear trialOrderNew
        for ii = 1:size(data.trialOrder,2)
            %loop through condition names and rename them using the matched
            %names table
            temp = data.trialOrder(ii);
            idx = matchNames.Original == temp;   % logical index
            trialOrderNew{ii} = cell2mat(matchNames.New(idx));
        end
        data.trialOrder = trialOrderNew;
        
    end
    
    %loop through trial order and place each fft in approriate cell array
    for iii = 1:size(data.trialOrder,2)
        %if its the first participant create a new cell
        if id == 1
            for iiii = 1:size(data.trialOrder,2)
                feval(@()assignin('caller',strcat(data.trialOrder{iiii},'_fft'),...
                    data.fftdata{iiii}));
            end
            %if it's not the first participant concatenate the cells
        else
            temp = data.fftdata{iii};
            eval(strcat(data.trialOrder{iii},'_fft',...
                ' = cat(1,',data.trialOrder{iii},'_fft,',...
                'temp);'))
            
        end
    end
end

%%Get average ffts for each condition
clc
disp('Calculating averages...')

%Calculate average fft for each condition
for iiiii = 1:size(data.trialOrder,2)
    eval(strcat(data.trialOrder{iiiii},'_nonbase',...
        ' = mean(',data.trialOrder{iiiii},'_fft,1);'));
end

%Do another baseline correction to make all bins zeros or non-zeros
for iiiiii = 1:size(data.trialOrder,2)
    eval(strcat(data.trialOrder{iiiiii},'_avg = ',...
        ' noisefloor3(',data.trialOrder{iiiiii},'_nonbase,[2 3],',...
        'data.fftbins);'))
end

%% plot
freqLim = inputdlg('What is the higest frequency you want to plot?');
freqLim = str2num(freqLim{1});

%determine the bin size
binsize = data.fftbins(2) - data.fftbins(1);

%determine the position of the highest frequency in the frequency bin
%vector
[minval,freqLimInd] = min(abs(data.fftbins - freqLim));

%sometimes the fftbins do not start at zero, if you need to determine how
%many bins it is off by for the plot
if data.fftbins(1) ~= 0
    numfromzero = (data.fftbins(1)/binsize) + 1;
else
    numfromzero = 1;
end

%find the range of frequnecies

for plotindex = 1:size(data.trialOrder,2)
    %Plot
    subplot(size(data.trialOrder,2)/2,...
        size(data.trialOrder,2)/2,...
        plotindex)
    hold on
    eval(strcat('plot(data.fftbins(numfromzero:freqLimInd + numfromzero - 1),',...
        data.trialOrder{plotindex},'_avg',...
        '(1:freqLimInd))'));
    xlabel('Frequencies (Hz)')
    ylabel('Amplitude (?V)')
    % eval(strcat('title(',data.trialOrder{plotindex},')'))
    hold off
    
end
end
