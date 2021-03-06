function rsam_wrapper(TOP_DIR, subnetName, datasourceObject, ChannelTagList, ...
    startTime, endTime, gulpMinutes, samplingIntervalSeconds, measures)
%RSAM_WRAPPER Compute RSAM data for long time intervals
%   rsam_wrapper(subnetName, datasourceObject, ChannelTagList, ...
%       startTime, endTime, gulpMinutes, samplingIntervalSeconds, measures)
%
%   rsam_wrapper(...) is a wrapper designed to move sequentially through
%   days/weeks/months of data, load waveform data into waveform objects,
%   compute RSAM objects from those waveform objects (using waveform2rsam)
%   and then save data from those RSAM objects into binary "BOB" files.
%
%   rsam_wrapper is actually a driver for iceweb2017. iceweb2017
%   will drive other products such as spectrograms and helicorders if
%   asked. But rsam_wrapper asks it only to compute RSAM data.
%
%   Inputs:
%
%       subnetName - (string) usually the name of a volcano
%
%       datasourceObject - (datasource) tells waveform where to load data
%                          from (e.g. IRIS, Earthworm, Antelope, Miniseed). 
%                          See WAVEFORM, DATASOURCE.
%       
%       ChannelTagList - (ChannelTag.array) tells waveform which
%                        network-station-location-channel combinations to
%                        load data for. See CHANNELTAG.
%
%       startTime - the date/time to begin at in datenum format. See
%                   DATENUM.
%
%       endTime - the date/time to end at in datenum format. See
%                   DATENUM.
%
%       gulpMinutes - swallow data in chunks of this size. Minimum is 10
%                     minutes, maximum is 2 hours. Other good choices are
%                     30 minutes and 1 hour.
%
%       samplingIntervalSeconds - compute RSAM with 1 sample from this many
%                             seconds of waveform data. Usually 60 seconds.
%                             See also WAVEFORM2RSAM. If multiple measures
%                             are used (see below) you can give multiple
%                             sampling intervals, e.g.
%                                   measures = {'mean';'max';'median'}
%                                   samplingIntervalSeconds = [60, 10, 600]
%                             But if you want them all to be the same,
%                             you only need pass a scalar.
%
%       measures - each RSAM sample is usually the 'mean' of each 60 second
%                  timewindow. But other stats are probably better. For
%                  events, 'max' works better. For tremor, 'median' works
%                  better. To compute multiple versions of RSAM using
%                  different stats, use a cell array, 
%                                         e.g. measures = {'max';'median'}.
%
% Example:
%       datasourceObject = datasource('antelope', '/raid/data/sakurajima/db')
%       ChannelTagList(1) = ChannelTag('JP.SAKA.--.HHZ');
%       ChannelTagList(2) = ChannelTag('JP.SAKB.--.HHZ');
%       startTime = datenum(2015,5,28);
%       endTime = datenum(2015,6,8);
%       gulpMinutes = 10;
%       samplingIntervalSeconds = 60;
%       measures = {'mean'};
%       rsam_wrapper('Sakurajima', datasourceObject, ChannelTagList, ...
%                     startTime, endTime, gulpMinutes, ...
%                     samplingIntervalSeconds, measures) 
%
% See also: iceweb.iceweb2017

if ~isa(measures,'cell')
    measures = {measures};
end

% set up products structure for iceweb
products.waveform_plot.doit = true;
products.rsam.doit = true;
products.rsam.samplingIntervalSeconds = samplingIntervalSeconds;
products.rsam.measures = measures;
products.spectrograms.doit = false;
products.spectrograms.timeWindowMinutes = 10;
products.spectral_data.doit = false;
products.spectral_data.samplingIntervalSeconds = samplingIntervalSeconds;
products.reduced_displacement.doit = false;
products.reduced_displacement.samplingIntervalSeconds = samplingIntervalSeconds;
products.helicorders.doit = false;
products.helicorders.timeWindowMinutes = [];
products.soundfiles.doit = false;

% call iceweb_wrapper
iceweb.iceweb2017(TOP_DIR, subnetName, datasourceObject, ChannelTagList, startTime, endTime, gulpMinutes, products)

disp('COMPLETED')