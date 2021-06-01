function entrain_entrainment
%
%This script is the second script in the neural entraiment pipeline. Run it
%only after you have run "entrain_preprocess". The scrpt performs an FFT on
%epoched continious data. It also prefroms a baseline subtraction based on
%methods used in Nozaradan et al. 2011. Entrainment to a speicifc freuqncy
%bin is caluclated based on an average power across 3 bins centered on the
%frequency of interest. Entrainment values are saved to a .csv
%in .../EntrainmentAnalysis/data/enTable. A .mat file is also created
%which contains: FFT data, Order of trails, frequency and averaged EEG data
%this %saved in .../EntrainmentAnalysis/data/FFT. 
%
%written by Sean Gilmore 2018, 
%last revised Dec. 2020
%
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clc
%% Set up directories and list files
if ispc == true
    parentDir = cell2mat(inputdlg('Enter the directory of the EntrainmentAnalysis folder'));
    addpath(parentDir)
else
    waitfor(msgbox('Press OK to select the location of the EntrainmentAnalysis folder'));
    parentDir = uigetdir;
end

%Add the directory of the third party functions used
addpath(genpath(fullfile(parentDir,'thirdpartyFunctions')));

%Make list of processed files
filedir = fullfile(parentDir,'data/processed');
files = dir(fullfile(parentDir,'data/processed'));
files = {files.name};
ind = ~cellfun(@isempty,(regexp(files,'\.set$')));
files = files(ind);

%% Define defults
%promt user to enter the frequeny of interest that will be used to
%calculate neural entrainemnt 
beatFreq = inputdlg('What is the frequency of interest?');
beatFreq = str2num(beatFreq{1});

%number of bins on either side of tempo bin (defult is 2) that will be
%averaged across to calculate neural entrainemnt value 
binwidth = inputdlg('Number of bins on each side of frequency of interest (defult = 2)');
if isempty(binwidth{1}) == true
    binwidth = 2;
else
    binwidth = str2num(binwidth{1});
end

%% Loop through files and calculate FFT and entrainemnt
for id = 1:size(files,2)
    files{id}
    %Load the EEG .set file
    EEG = pop_loadset(fullfile(parentDir,'data/processed/',files{id}));
    
    %Determine the bin width based on sample rate of EEG
    nfft = EEG.srate/(1/(size(EEG.data,2)/EEG.srate)); % sample rate/(1/length of epoch)
    
    %Compile a list of conditions based on the EEG.urevents
    if isempty(EEG.event) == true
        eventTable = struct2table(EEG.urevent);
        correctEvent = inputdlg(num2str(unique(eventTable.type)),...
            'Are all these events correct(yes or no)?',...
            [1 100]);
        if strcmp(correctEvent,'no')
            %promt user to list the incorrect events
            incorrectEvents = inputdlg(num2str(unique(eventTable.type)),...
                'List the events that need to be removed [1 2 4 n...]?',...
                [1 100]);
            incorrectEvents = cell2mat(incorrectEvents);
            incorrectEvents = str2num(incorrectEvents);
            %make a list of events that correspond to the users input
            temp = cell2mat({EEG.urevent.type});
            events2keep = find(~ismember(temp,incorrectEvents));
            events = temp(events2keep);
            eventTypes = unique(events,'stable');
        else
        end
    else
    end
    
    %create data strucutre that will be exported
    data.trialOrder = eventTypes;
    
    %loop through unique events and create average EEG datasets then store
    %them all in a structure 
    for index = 1:size(eventTypes,2)
        
        %find what trials correspond to unique event type
        cond = find(ismember(events,eventTypes(index)));
        cond = EEG.data(:,:,cond);
        cond = mean(cond,3);
        
        if index == 1
            data.avg{index} = cond;
        else
            data.avg{index} = cond;
        end
        
    end

%% Calculate the FFT across all electrodes
for i = 1:length(data.avg)
    
    %compute fft, plot and calculate entrainment using the getfft3 function
    %in the "entrainment" toolbox written by Gabe Nespoli
    [yfft, f] = getfft3( ...
        data.avg{i}, ...
        EEG.srate, ...
        'spectrum',     'amplitude', ...
        'nfft',         nfft,...
        'detrend',      false, ...
        'wintype',      'hanning', ...
        'ramp',         [], ...
        'dim',          2); % should the the time dimension
    
    [fftdata, freqbin] = noisefloor3(yfft, [2 3], f);
    
    data.fftdata{i} = fftdata;
end

%add the frequency bin vector to the structure 
data.fftbins = freqbin;


%save the strucutre with the FFT data, average EEG signals and trial order
%which can be used for plotting.
save(fullfile(parentDir,'data/FFT',EEG.setname(1:3)),...
    'data');

%% Calculate entrainment
%create a cell array of zeros that will contain entrainment values 
en = zeros(size(fftdata,1), size(beatFreq,2), size(data.fftdata,2));

for enIndex = 1:size(en,3) % loop trials
    %calculate entrainemnt using "getbins3" function from the entrainment
    %toolbox wirtten by Gabe Nespoli
    en(:,:, enIndex) = getbins3( ...
        data.fftdata{enIndex}, ...
        freqbin, ...
        beatFreq, ... %freqs of beat rate and harmonics
        'width', 1, ...
        'func',  'mean');
end

%calculate mean of all nonZeros acorss all electrodes
for ii = 1:size(en,3)
    en_temp = mean(nonzeros(en(:,:,ii)));
    
    %concatenate mean across trials
    if ii == 1
        en_mean = en_temp;
    else
        en_mean(ii) = en_temp;
    end
end
EN_mean = en_mean;


%% Make entrainment table
%make table with entrainment values,ROIs,and events

rows = data.trialOrder;
%make table
participantColumn = repmat(EEG.setname(1:3),[length(rows) 1]);
t = table(participantColumn,EN_mean',rows');
t.Properties.VariableNames = {'id' 'EN_mean' 'Trials'};

if id == 1
    T = t;
else
    T = vertcat(T,t);
end

end

%save the entrianmentTable.csv
writeDir = fullfile(parentDir,'data','enTable','entrainmentTable.csv');
writetable(T,writeDir);

end
