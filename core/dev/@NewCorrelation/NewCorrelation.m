classdef NewCorrelation
   %Correlation
   %  Authored by Mike West, Geophysical Institute, Univ. of Fairbanks
   %  rewritten into the new MATLAB classes by Celso Reyes
   
   %TODO: writing traces is inefficient because of set.traces. convert this
   %to both an internal and external version, where internal TRUSTS always
   %a column, and external doesn't.
   
   properties
      traces %  % c.W
      trig % will be triggers; % c.trig
      corrmatrix % correlation similarity matrix
      lags % will be lags; % c.L
      stat % will be statistics; % c.stat
      link % might be links;% c.link
      clust % will be clusters;% c.clust
   end
   
   properties(Dependent, Hidden)
      % properties that existed prior to rewrite
      W % traces as waveforms
      C % correlation matrix corrmatrix
      L % Lags
   end
   properties(Dependent)
      % new properties
      ntraces % number of traces
      data_length % length of first trace (should all be same)
      
      % properties associated with the waveforms / traces
      stations % station name for each trace
      channels % channel name for each trace
      networks % network name for each trace
      locations % location name for each trace
      
      samplerate % sample rate (for first trace)
      data % all the trace's data as a matrix
   end
   
   methods
      function c = NewCorrelation(varargin)
         % CORRELATION Correlation class constructor, version 1.5.
         %
         % C = CORRELATION creates an empty correlation object. For explanation see the
         % description below that follows the usage examples.
         %
         % C = CORRELATION(SeismicTrace)
         % Create a correlation object from an existing waveform object. In a pinch
         % this formulation can be used, however, it lacks one critical element.
         % Without a trigger time, the correlation object has no information about
         % how the traces should be aligned. With clean data this may be remedied
         % with the XCORR routine. If possible however, it is better to use one of
         % the CORRELATION uses which includes trigger times. In the absence of this
         % information, trigger times are arbitrarily assigned to be one quarter of
         % the time between the trace start and end times.
         %
         % C = CORRELATION(WAVEFORM,TRIG)
         % Create a correlation object from an existing waveform object and a column
         % vector of trigger times. These times can be in the matlab numeric time
         % format (serial day) or a recognized string format (see HELP DATENUM).
         % TRIG must be the same length as WAVEFORM or be a scalar value.
         %
         % CORRELATION('DEMO') DEPRECATED
         % use   NewCorrelation.demo()   instead
         %
         % C = CORRELATION(datasource,scnlobjects,trig,pretrig,posttrig)
         % creates a correlation object using the sta/chan/net/loc codes contained
         % in SCNLOBJECT loaded from the datasource defined by DATASOURCE. For help
         % in understanding the SCNLOBJECT and DATASOURCE object, see HELP
         % SCNLOBJECT and HELP DATASOURCE respectively.
         %
         % Start and end trace times are based on an input list of trigger times
         % cropped according to the pre/posttrig terms. All traces in the resulting
         % correlation object have the same frequency and the same number of
         % samples. If partial data is returned from the database request,
         % traces are zero-padded accordingly. If a trace has a lower frequency than
         % other traces in the object, a warning is issued and the trace is
         % resampled to the highest frequency in the set of waveforms. For most uses
         % this should be a rare occurence.
         %
         %The inputs are:
         %       datasource:     station name
         %       scnlobject:     scnlobject
         %       trig:           vector of absolute trigger times
         %                         (in matlab serial time format)
         %       pre/posttrig:   these times in seconds define the width of the
         %                       window for each trace, where pretrig and posttrig
         %                       are times in seconds relative to the trigger
         %                         time.
         %
         % C = CORRELATION(C,W)  DEPRECATED
         % use: C.traces = W
         %   This will make sure that things are compatible
         % ORIGINAL DESCRIPTION BELOW
         % replaces the waveforms in correlation object C with
         % the waveform object W. This is useful for manipulating waveforms with
         % tools outside the correlation toolbox.
         % Example:
         %   % square the amplitudes of each trace (sign-sensitive)
         %   w  = waveform(c);
         %   w1 = (w.^2)
         %   w2 = sign(w);
         %   for n = 1:numel(w)
         %        w(n) = w1(n) .* w2(n);
         %   end
         %   c = correlation(c,w);
         % This is a very convenient usage since the correlation toolbox will never
         % incorporate all the possible waveform manipulations one might want.
         % However it needs to be used with care. It is possible to manipulate the
         % extracted waveform in ways that make it incompatible with the rest of the
         % metadata in the correlation object - for example if the times stamps are
         % altered. When replacing the waveform in a correlation object, all derived
         % data fields (CORR, LAG, LINK, STAT, CLUST) are removed since this data is
         % presumed no longer valid.
         %
         % C = CORRELATION(N) where N is a single number, creates a correlation
         % object with N randomly generated simplistic synthetic traces. At times
         % useful for offline testing.
         %
         % C = CORRELATION(CORAL) where CORAL is a data structure from the CORAL
         % seismic package (K. Creager, Univ. of Washington). CORAL is a fairly
         % comprehensive seismic data and metadata format. CORRELATION and
         % the underlying WAVEFORM suite are not. A CORAL to CORRELATION conversion
         % should usually be easy. The other direction may be more challenging as
         % most correlation and waveform objects do not contain much of the "header"
         % info stored by CORAL. If the pPick field exists in the CORAL structure,
         % then it is used to set the trigger times inside the resulting correlation
         % object. NOTE that little error checking is performed on the CORAL
         % structure. If it is improperly constructed, then the conversion to a
         % correlation object may fail without an intelligible error message.
         %
         %
         %
         % % ------- DESCRIPTION OF FIELDS IN CORRELATION OBJECT ------------------
         % All calls to correlation return a "correlation object" containing
         % the following fields where M is the number of traces:
         %    TRIG:     trigger times in matlab serial time (Mx1)
         %    WAVES:    vector of waveforms (Mx1)
         %    CORR:     max correlation coefficients (MxM, single precision)
         %    LAG:      lag times in seconds (MxM, single precision)
         %                (Example: If the lag time in position (A,B) is positive,
         %                 then similar features on trace A occur later in relative
         %                 time than on trace B. To align the traces, the lag time
         %                 in (A,B) must be added to the trigger time of A)
         %    STAT:     statistics about each trace (Mx? see below)
         %    LINK:     defines the cluster tree (Mx3)
         %    CLUST:    defines individual clusters(families) of events (Mx1)
         %
         % The first two fields define the data traces. The last five fields are
         % products derived from these data. (Programming note: Internally, these
         % fields are referred to as c.trig, c.W, c.corrmatrix, c.lags, c.stat, c.link, and
         % c.clust, respectively.)
         %
         % The STAT field contains columns of statistics that can be assigned one
         % per trace. The number of columns may be expanded to accomodate
         % additional parameters. Currently it is 5 columns wide. Column 1 is the
         % mean maximum correlation. Column 2 is the high side rms error (1 sigma)
         % of the mean max correlation. Column 3 is the low side rms error (1
         % sigma) of the mean max correlation. Columns 4 is the unweighted least
         % squares best fit delay time for each trace. Column 5 is the rms error of
         % this delay time. See Vandecar and Crosson (BSSA 1990) and HELP GETSTAT
         % for details of how these statistics are calculated.
         %
         %
         % It is worth first investing time to understand the WAVEFORM, DATASOURCE,
         % SCNLOBJECT objects on which CORRELATION is built.
         % See also datasource waveform scnlobject
         
         % CHECK THAT WAVEFORM IS SET UP
         if ~exist('waveform','file')
            error('The Waveform Suite must be in the path to use the correlation toolbox.')
         end
         
         % LOAD DATA VIA WAVEFORM. SEND SPECIAL CASES TO SUBROUTINE
         
         for nm=1:numel(varargin)
            if isa(varargin{nm},'waveform')
               varargin{nm} = SeismicTrace(varargin{nm});
            end
         end
         

         switch nargin
            case 0
               return; % create a blank (default) NewCorrelation object
            case 1
               switch class(varargin{1});
                  case 'SeismicTrace'
                     % USAGE: NewCorrelation(SeismicTrace) load from waveforms (no specified triggers)
                     c.traces = varargin{1};
                     c.trig = c.traces.firstsampletime() + 0.25*(get(c.W,'END') - c.traces.firstsampletime());
                     c.trig = reshape(c.trig,numel(c.trig),1);
                     
                  case 'correlation'
                     % USAGE: NewCorrelation(correlation), make new from old
                     c = c.convertFromOld(varargin{1});
                     
                  case {'double'}
                     % USAGE: NewCorrelation(N), make synthetic data for N traces
                     co = makesynthwaves(varargin{1});
                     c.W = co.W;
                     c.trig = co.trig;
                     
                  case 'struct'
                     % USAGE: NewCorrelation(coralStruct)
                     if NewCorrelation.mightBeCoral(varargin{1})
                        c = convert_coral(varargin{1});
                     end
               end
            case 2
               if isa(varargin{1},'correlation')
                  % TODO: finesse this error
                  error('set the waveforms in the correlation object instead\n c.traces = w');
                  % USAGE: NewCorrelation(NewCorr, W), replace waveforms
                  c = varargin{1};
                  w = varargin{2};
                  if c.ntraces ~= numel(w)
                     error('Correlation and waveform objects must have the same number of elements');
                  end
                  c.traces = w;
               elseif isa(varargin{1},'SeismicTrace')
                  % USAGE: NewCorrelation(traces, triggers), populate with waveform and triggers
                  assert(isnumeric(c.trig), 'Time format for TRIG field not recognized');
                  c.traces = varargin{1};
                  c.trig = varargin{2};
                  c.trig = reshape(c.trig,numel(c.trig),1);
                  % adjust length of trigger field input
                  if numel(c.trig)==1
                     c.trig = c.trig*ones(size(c.traces));
                  elseif  numel(c.trig)~=numel(c.traces)
                     error('correlation:correlation:wrongTriggerLength',...
                        'Trigger argument must be of length 1 or the same as the number of waveforms');
                  end
               end
            case 5  % build from a datasource
               % USAGE: NewCorrelation(ds, scnl, trig, pretrig, posttrig)
               assert(isa(varargin{1},'datasource'));
               [ds, scnl, trig_, pretrig, posttrig] = deal(varargin{:});
               trig_ = reshape(trig_,length(trig_),1);
               c = loadfromdatasource(ds, scnl, trig_, pretrig, posttrig);
               c = unifytracelengths(c);
               c = crop(c,pretrig,posttrig);
            otherwise
            error('Invalid input values to correlation');
         end
         
         %% REMOVE TRENDS AND ADJUST DATA LENGTH AND SAMPLE RATE IF NECESSARY
         if ~isempty(c.traces)
            c = demean(c);
            c = detrend(c);
            if ~check(c,'FREQ')
               c = align(c);
            elseif ~check(c,'SAMPLES')
               c = unifytracelengths(c);
            end
         end
         
         
         
         
         
         %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
         %% FUNCTION: LOAD WAVEFORM DATA FROM A DATASOURCE
         %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
         function c = loadfromdatasource(ds,scnl,trig,pretrig,posttrig)
            
            % TODO: This function needs to rewritten if/when waveform is able to
            % identify which traces are empty instead of skipping them. This should
            % improve the spead considerably. - MEW, May 25, 2009.
            
            % READ IN WAVEFORM OBJECTS
            good = true(size(trig));
            fprintf('Reading waveforms into a correlation object ...\n');
            w = waveform;
            nMax = length(trig);
            disp('     ');
            
            %all requests for waveforms are the same, and depend upon various triggers.
            wgetter = @(tr) waveform(ds, scnl, tr+pretrig/86400, tr+posttrig/86400);
            
            loaderrmsg = [get(scnl,'nscl_string'), ' at time %s could not be loaded\n     \n'];
            updatemsg.good = @(n) fprintf('\b\b\b\b\b\b%5.0f%%',n/nMax*100);
            updatemsg.bad = @(dv) fprintf(loaderrmsg, datestr(dv,'mm/dd/yyyy HH:MM:SS'));
            
            for n = 1:nMax
               try
                  w(n) = wgetter(trig(n));
                  updatemsg.good(n);
               catch
                  updatemsg.bad(trig(n));
                  good(n) = false;    % mark waveform as empty
               end;
            end;
            fprintf('\n');
            %
            % CHECK TO SEE IF ANY DATA WAS READ IN
            if numel(w)==0
               error('This data is not available from the specified database.');
            end
            
            % FILL DATA GAPS
            w = fillgaps(w,'MeanAll');
            
            %
            % STORE ONLY GOOD TRACES
            w = w(good);
            trig = trig(good);
            %
            % FILL CORRELATION STRUCTURE
            c.W = reshape(w,length(w),1);
            c.trig = reshape(trig,length(trig),1);
         end
         
         %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
         %% FUNCTION: LOAD AN ANTELOPE DATABASE
         %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
         
         function c = loadfromantelope(stat,chan,trig,pretrig,posttrig,archive)
            
            % READ IN WAVEFORM OBJECTS
            good =true(size(trig));
            fprintf('Creating matrix of waveforms ...');
            wf = waveform;
            
            for i = 1:length(trig)
               try
                  if ~isnan(archive)
                     wf(i) = waveform(stat,chan,trig(i)+pretrig/86400,trig(i)+posttrig/86400,archive);
                  else
                     wf(i) = waveform(stat,chan,trig(i)+pretrig/86400,trig(i)+posttrig/86400);
                  end
                  freq(i) = get(wf(i),'Fs');
                  fprintf('.');
               catch
                  disp(' ');
                  disp([stat '_' chan ' at time ' datestr(trig(i),'mm/dd/yyyy HH:MM:SS.FFF') ' could not be loaded.']);
                  good(i) = false;    % mark waveform as empty
               end;
            end;
            disp(' ');
            %
            % CHECK TO SEE IF ANY DATA WAS READ IN
            if length(wf)==0
               error('This data not is available from the specified database.');
            end
            %
            % STORE ONLY GOOD TRACES
            wf = wf(good);
            trig = trig(good);
            freq = freq(good);
            %
            % FILL CORRELATION STRUCTURE
            c.W = reshape(wf,length(wf),1);
            c.trig = reshape(trig,length(trig),1);
         end
         
         
         
         %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
         %% FUNCTION: LOAD FROM A WINSTON DATABASE
         %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
         
         function c = loadfromwinston(stat,chan,trig,pretrig,posttrig,netwk,loc,server,port)
            
            % READ IN WAVEFORM OBJECTS
            good = true(size(trig));
            fprintf('Creating matrix of waveforms ...');
            wf = waveform;
            for i = 1:length(trig)
               try
                  wf(i) = waveform(stat,chan,trig(i)+pretrig/86400,trig(i)+posttrig/86400,netwk,loc,server,port);
                  freq(i) = get(wf(i),'Fs');
                  fprintf('.');
               catch
                  disp(' ');
                  disp([stat '_' chan ' at time ' datestr(trig(i),'mm/dd/yyyy HH:MM:SS.FFF') ' could not be loaded.']);
                  good(i) = false;    % mark waveform as empty
               end;
            end;
            disp(' ');
            %
            % CHECK TO SEE IF ANY DATA WAS READ IN
            if numel(wf)==0
               error('This data not is available from the specified database.');
            end
            %
            % STORE ONLY GOOD TRACES
            wf = wf(good);
            trig = trig(good);
            freq = freq(good);
            %
            % RESAMPLE TRACES TO MAXIMUM FREQUENCY
            fmax = round(max(freq));
            for i = 1:length(trig)
               if get(wf(i),'FREQ') ~= fmax
                  wf(i) = align(wf(i),trig(i),fmax);
                  disp(['Trace no. ' num2str(i) ' is being resampled to ' num2str(fmax) ' Hz']);
               end
            end
            %
            % FILL CORRELATION STRUCTURE
            c.W = reshape(wf,length(wf),1);
            c.trig = reshape(trig,length(trig),1);
         end
         
         
         %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
         %% FUNCTION: CONVERT FROM CORAL STRUCTURE
         %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
         
         function c = convert_coral(coral)
            
            w = waveform;
            t = zeros(size(coral));
            for i = 1:length(coral)
               w(i) = waveform;
               w(i) = set( w(i) , 'Station' , coral(i).staCode );
               w(i) = set( w(i) , 'Channel' , coral(i).staChannel );
               w(i) = set( w(i) , 'Data' , coral(i).data );
               w(i) = set( w(i) , 'Start' , datenum(coral(i).recStartTime') );
               w(i) = set( w(i) , 'FREQ' , 1/coral(i).recSampInt );
               if isfield(coral(i),'pPick')
                  t(i) = datenum(coral(i).pPick');
               end
            end
            
            if length(find(t))==length(t)
               disp('Trigger times are being applied from coral pPick field');
               c = NewCorrelation(w,t); %was correlation
            else
               c = NewCorrelation(w); %was correlation
            end
            %c.W = reshape(w,length(w),1);
         end %convert_coral
      end %NewCorrelation
      
      %{
      Note about setting NewCorrelation fields:
      %}
      function waves = get.W(obj)
         warning('getting waveforms instead of traces');
         waves = waveform(obj.traces);
      end
      function obj = set.W(obj, waves)
         % warning('setting waveforms instead of trace');
         obj.traces = SeismicTrace(waves);
      end
      function X = get.C(obj)
         warning('use c.corrmatrix instead of c.C')
         X = obj.corrmatrix;
      end
      function obj = set.C(obj, C)
         warning('use c.corrmatrix instead of c.C')
         obj.corrmatrix = C;
      end
      function X = get.L(obj)
         warning('use c.lags instead of c.L')
         X = obj.lags;
      end
      function obj = set.L(obj, lags)
         warning('use c.lags instead of c.L')
         obj.lags = lags;
      end
      
      function c = set.traces(c, T)
         % NOTE: To avoid problems with "subset", size of T is not checked!
         c.traces = T(:); % ensure traces are in a column
         %TODO: Should this also wipe all the calculated values?
      end
      
      function sta = get.stations(obj)
         sta = {obj.traces.station};
      end
      function net = get.networks(obj)
         net = {obj.traces.network};
      end
      function loc = get.locations(obj)
         loc = {obj.traces.location};
      end
      function cha = get.channels(obj)
         cha = {obj.traces.channel};
      end
      
      function n = get.ntraces(obj)
         n = numel(obj.traces);
      end
      
      function sr = get.samplerate(obj)
         sr = obj.traces(1).samplerate;
      end
      function n = get.data_length(obj)
         n = obj.traces(1).nsamples;
      end
      
      function n = relativeStartTime(c, i)
         %relativeStartTime  start time, relative to trigger
         %  t = c.relativeStartTime(index) will return the relativeStartTime
         %  of the indexth trace, by subtracting the indexth trigger
         
         n = 86400 * (c.traces(i).firstsampletime() - c.trig(i));
      end
      
      
      function maybeReplaceYticksWithStationNames(c,ax)
         % replace dates with station names if stations are different
         if ~check(c,'STA')
            labels = strcat(c.stations , '_', c.channels);
            set( ax , 'YTick' , 1:1:c.ntraces);
            set( ax , 'YTickLabel' , labels );
         end
      end
      
      %% functions that exist in other files
      c = adjusttrig(c,varargin)
      
      c = agc(c,windowInSeconds)       % automatic gain control      
      c = align(c,alignFrequency)      
      c = butter(c,varargin)      
      c = cat(varargin)
      val = check(c,whatToCheck)
      c = cluster(c,varargin)
      c = colormap(c,mapname)
      c = conv(c)
      c = crop(c, pretrig, posttrig)
      % c = deconv(c)  remarked out because it isn't working yet.
      c = demean(c)
      c = detrend(c)
      c = diff(c)
      disp(c)
      index = find(c,type, value)
      family = getclusterstat(c)
      c = getstat(c)
      c = hilbert(c,n)
      c = integrate(c)
      [c,t,i,CC,LL] = interferogram(c, width, timestep, masterIdx)
      c = linkage(c,varargin)
      [c1,c2] = match(c1,c2,toleranceInSeconds)
      c = minus(c,I)
      c = norm(c,varargin)
      plot(c,varargin)
      c = sign(c)
      c = sort(c)
      c = stack(c,index)
      c = strip(c)
      c = subset(c,index)
      c = taper(c,varargin)
      w = waveform(c,varargin)
      writedb(c,dbOut,varargin)
      c = xcorr(c,varargin)
      
   end %methods
   
   methods(Access=private)
      corrplot(c)
      dendrogramplot(c);
      eventplot(c,scale,howmany)
      A = getval(OBJ,PROP)
      lagplot(c);
      c = makesynthwaves(n);
      occurrenceplot(c,scale,clusternum)
      overlayplot(c,scale,ord)
      sampleplot(c,scale,ord)
      shadedplot(c,scale,ord)
      statplot(c);
      c = unifytracelengths(c)
      wiggleinterferogram(c,scale,type,norm,range)
      wiggleplot(c,scale,ord,norm)
      
      function c = convertFromOld(c, oldC)
         c.W = get(oldC,'waves'); %  % c.W
         c.trig = get(oldC,'trig'); % will be triggers; % c.trig
         c.corrmatrix = get(oldC,'corr');
         c.lags = get(oldC,'lag');% will be lags; % c.L
         c.stat = get(oldC,'stat'); % will be statistics; % c.stat
         c.link = get(oldC,'link'); % might be links;% c.link
         c.clust = get(oldC,'clust');% will be clusters;% c.clust
      end
   end
   
   methods(Hidden)
      %These methods still work, but aren't being promoted
      c = set(c, prop_name, val); % instead of set, use direct access
      val = get(c,prop_name) % instead of get, use direct access
   end
   
   methods(Static)
      correlationVariables = cookbook(corr)
      function c = demo()
         % demo   load the demo dataset
         % Opens the demo dataset for correlation. This dataset contains a single
         % correlation object of 100 traces. It is the data source for the cookbook
         % demos.
         
         % TODO: Resave data file as NewCorrelation
         oldcorrobj = load('demo_data_100'); %stresstest
            c = NewCorrelation(oldcorrobj.c);
      end
         
   end
   
   methods(Access=private, Static)
      % d = xcorr1x1(d);
      d = xcorr1xr(d,style)
      % d = xcorr1xr_orig(d)
      % d = xcorrdec(d)
      d = xcorrrow(d,c,index)
      function m = fillLowerTriangleFromUpper(m)
         % FILL LOWER TRIANGULAR PART OF MATRICES
         m = m + m' - eye(size(m));
      end
      
      function tf = mightBeCoral(aStruct)
         tf = isfield(aStruct,'data') && isfield(aStruct,'staCode') && isfield(aStruct,'staChannel');
      end
   end
end


