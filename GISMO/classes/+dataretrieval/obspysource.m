classdef obspysource < dataretrieval.spatiotemporal_file
   %UNTITLED2 Summary of this class goes here
   %   Detailed explanation goes here
   
   properties
   end
   
   methods
      function data = retrieve(obj, where_, from_ , until_)
         error('unimplemented obspy data source');
      end
      
      function out_ = translate(obj, in_)
         
      end
   end
   
end
