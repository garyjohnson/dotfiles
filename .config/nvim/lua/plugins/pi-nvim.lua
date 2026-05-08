return {                                                                                                           
   'pi-nvim',
   dev = true,  -- Tells lazy to treat this as a development plugin                                          
   config = function() 
         require('pi-nvim').setup()
   end 
}
