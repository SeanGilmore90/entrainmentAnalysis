function [EEG] = interpol( EEG, chanlocs, method )
%INTERPOL Performs channel interpolation on eeglab EEG structure
%   Receives the EEG structure (see EEGLAB documentation), the disered final chanlocs to
%   have on the data and the interpolation method and the algorithm finds the missing
%   channels in the EEG structure and calls the pop_interp method from EEGLAB toolbox to
%   compute the interpolations. Afterwords sorts the channels to the provided chanlocs
%   order and fixes the icachansind field.
%   
%   Input:
%   EEG         -   the EEG structure (EEGLAB)
%   chanlocs    -   cell array of channels specification (taken from EEG.chanlocs before 
%                   removing channels)
%   method      -   ['spherical' (default)] interpolation method
%
%   Output:
%   EEG         -   EEG structure with the new electrodes and respective signal added in 
%                   the right places
%
%   Author: Marco Simões (msimoes@dei.uc.pt) 2015 - All rights reserved

    if nargin < 3
        method = 'spherical';
    end

    % get a list of existent chanloc names in the EEG structure
    chans_eeg = [];
    for i=1:length(EEG.chanlocs)
        chans_eeg = [ chans_eeg {EEG.chanlocs(i).labels} ];
    end

    % make a list of indexes from the provided chanlocs that are not in the EEG structure
    idxs = [];
    for i=1:length(chanlocs)
        if isempty(find(ismember(chans_eeg, chanlocs(i).labels) == 1, 1))
            idxs = [idxs i];
        end
    end

    % call EEGLAB pop_interp method
    EEG = pop_interp(EEG, chanlocs(idxs), method);

    %% reorder

    % get current EEG chanlocs names
    chans_eeg = cell(1, length(EEG.chanlocs));
    for c=1:length(EEG.chanlocs)
        chans_eeg{c} = EEG.chanlocs(c).labels;
    end

    % find order idxs
    idxs = nan(1, length(chanlocs));
    for c=1:length(chanlocs)
        idxs(c) = find(ismember(chans_eeg, chanlocs(c).labels) == 1, 1);
    end

    % reorder data and chanlocs based on indexes
    EEG.data(:,:) = EEG.data(idxs,:);
    EEG.chanlocs = EEG.chanlocs(idxs);

    % updata icachansind for a correct match to the channels used in ica
    indcomps = nan(1, length(EEG.icachansind));
    for compidx = 1:length(EEG.icachansind)
        indcomps(compidx) = find(EEG.icachansind(compidx) == idxs);
    end
    EEG.icachansind = indcomps;

end
