function entrain_preprocess

%This script is used to pre-process continious EEG data with the intention
%of looking at nerual entrainemnt of delta band freuqneices to a extenral
%stimulus. The pipline is based on  pipline designed by Makoto Miyakoshi 
%(https://sccn.ucsd.edu/wiki/Makoto's_preprocessing_pipeline).
%To run, the user most have the most recent version of EEGlab install. This can be
%found at https://sccn.ucsd.edu/eeglab/index.php.
%
%
%written by Sean Gimore 2018
%last revised Dec. 2020
%
%Before running...
%1)download the "EntrainmentAnalysis" folder located on the server. This contains all
%files, software and thirdparty functions needed for this analysis.
%2)Place all raw EEG files in the "rawData" folder located in
%EntrainmentAnalsis
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clc
%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Frist, set up pathways so that Matlab can locate certain files
%and/or software that will be used in the preprocessing of the data.

%Set up pathway to the folder "EntrainmentAnalysis". IF you are using Mac, you can use the
%pop up window. If you are using a PC then you will have to manually enter
%the directory in the popup window.
if ispc == 1
    parentDir = cell2mat(inputdlg('Enter the directory of the EntrainmentAnalysis folder'));
    addpath(parentDir)
else
    waitfor(msgbox('Press OK to select the location of the EntrainmentAnalysis folder'));
    parentDir = uigetdir;
end

%Determine the length of the epoch based on the length of your trials
trialLength = inputdlg('What was the duration of the trails in seconds?',...
    'Length of trial',...
    [1 20]);
trialLength = cell2mat(trialLength);
trialLength = str2num(trialLength);
%size of the epoch is 1 sec. after start of trail, and 3 seconds before
%end of trail.
    
%Add the directory of a file called 'Standard-10-5-Cap385_witheog.elp. This file is used to
%determien the location of the channels.
chanlocdir = fullfile(parentDir,...
    'eeglab14_1_2b/functions/resources/Standard-10-5-Cap385_witheog.elp');

%Add the directory of the third party functions used in the preprocessing
%of the data.
addpath(genpath(fullfile(parentDir,'thirdpartFunctions')));

%start up EEGlab
eeglab
clc

%find location of raw files that will be preprocessed
filedir = fullfile(parentDir,'data/raw');
files = dir(fullfile(parentDir,'data/raw'));
files = {files.name};
files = files(~ismember(files,{'.','..','Reject','.DS_Store','._.DS_Store'}));

%% loop through files and run preprocess pipeline
for id = 1:length(files)
    
    %Display which participant is being processes
    disp('Current file...')
    disp(files{id})
    
    %Loads the EEG (.bdf) file 
    EEG = pop_biosig(fullfile(filedir,files{id}),... %file
        'channels',1:137,...  %all channels
        'importevent','on',... %import events
        'ref',[]); %average reference
    EEG.setname = files{id}(10:12);
    
    %Remove Extra channel, rename channels and add channel locations
    EEG = pop_select(EEG, 'nochannel', 135:136); % remove EXG7 and EXG8
    EEG = alpha2fivepct(EEG, false); % relabels the channels base on 10-20 system
    EEG = pop_chanedit(EEG, 'lookup',chanlocdir); % add channel locations
    
    %Display the events/triggers from the recording. Here you can inspect
    %and determine if there is any spurious event, which can sometimes
    %happend from the recording
    eventTable = struct2table(EEG.event);
    correctEvent = inputdlg(num2str(unique(eventTable.type)),...
        'Are all these events correct(yes or no)?',...
        [1 100]);
    if strcmp(correctEvent,'no')
        %promt user to list the incorrect events
        incorrectEvents = inputdlg(num2str(unique(eventTable.type)),...
            'List the events that need to be removed in square brackets [1 2 4 n...]?',...
            [1 100]);
        incorrectEvents = cell2mat(incorrectEvents);
        incorrectEvents = str2num(incorrectEvents);
        %delete events that correspond to the users input
        events2delete = find(ismember([EEG(:).event.type],incorrectEvents));
        events2delete = 1:2:length(EEG.event);
        EEG = pop_editeventvals(EEG,'delete',events2delete);  
    else
    end   
    %% Preprocessing
    %Use the average across all electrodes as the reference from which
    %actiivty will be compared to. For further details see: 
    %https://sccn.ucsd.edu/wiki/Makoto's_preprocessing_pipeline#Re-reference_the_data_to_average_.2808.2F02.2F2020_Updated.29
    EEG.data = averageReference(EEG.data);
    
    %save original data before channel rejection. This will be used when interpolating channels
    EEG_org = EEG;
    
    %1)Filtering 
    %High pass filter @ 0.1 Hz (everything below 0.1 will be removed)
    EEG = pop_eegfiltnew(EEG, 0.1); % slowest beat is 1.25, group by 2 = 0.75
    
    %2)Reject channels that have a lot of noise using "clean_artifacts" function
    %Clean artifacts and channels
    EEG = clean_artifacts(EEG, ...
        'Highpass',         'off', ...
        'BurstCriterion',   'off', ...
        'WindowCriterion',  'off');
    
    %Rereference becaue we have rejected channels so now there is a new
    %average 
    EEG.data = averageReference(EEG.data);
    
    %This inperpolates the removed channels. Full array of channels is used
    %for plotting distrobution of entrainment across electrodes. 
    EEG = interpol(EEG,EEG_org.chanlocs,'spherical');
    
    %% Epoching
    %set the epoch to 1 s after the start of the trial and 3 seconds before
    %the end. 
    timelim = [1 trialLength-3]; 
    
    %Create a list of events where each epoch will be locked to
    eventTypes = [EEG.event(1:length(EEG.event)).type];
    eventTypes = regexp(num2str(eventTypes), '\s*', 'split'); % convert numeric to cell of strings
    
    %define event indicies
    eventIndices = 1:length(eventTypes);
    
    %Run the Epoching 
    EEG = pop_epoch(EEG, ...
        eventTypes, ...
        timelim, ...
        'newname', EEG.setname, ...
        'epochinfo','yes');
    
    %% Independent Component Analysis
    %Use EEGlab function to conduct an ICA analysis. Note: this will take a
    %long time.
    EEG = pop_runica(EEG, 'extended', 1);
    
    %Based on the components, use the ADJUST function to reject artifacts 
    %(https://www.nitrc.org/projects/adjust/)
    art = ADJUST(EEG,...
        fullfile(parentDir,'logFiles',strcat(EEG.setname,'_ADJUST_log')));
    EEG = pop_subcomp(EEG,art,0,0);
    
    %% save file
    EEG = pop_saveset(EEG, ...
        'filepath',fullfile(parentDir,'data/processed'), ...
        'filename', [EEG.setname,'.set']);
    
    %update the GUI window before the next particpant 
    eeglab redraw
end
end