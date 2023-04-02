// Feather ignore all
#macro __FASTSM_VERSION "1.0"
#macro __FASTSM_ENABLE_SAFETY   true
#macro __FASTSM_ENABLE_WARNINGS true
#macro __FASTSM_ENABLE_LOGGING  false

show_debug_message("FastSM::Version {0}", __FASTSM_VERSION);

// enter: function(this, before) {}
// leave: function(this, to) {}

/// @param {Real} size      Amount of total states
/// @param {Real} triggers  Amount of total triggers
function FastSM(_size, _trigger_count) constructor 
{
	#region VARIABLES
	var _this = self;
	
	/// @ignore calling instance
	__owner = other;
	
	/// @ignore amount of total states
	__size = _size;
	
	/// @ignore
	__states = array_create(__size, undefined);
	
	/// @ignore internal, used for technical reasons
	__states[0] = {name: "INTERNAL_state_not_a_state"};
	
	/// @ignore index of currently active state
	__state_active = 0;
	
	/// @ignore amount of total triggers
	__trigger_count = _trigger_count;
	
	/// @ignore
	__triggers = array_create(__trigger_count, undefined);
	
	/// @ignore default event map
	__default_events = { };
	
	/// @ignore
	__default_events[$ "enter"] = function() {  }
	
	/// @ignore
	__default_events[$ "leave"] = __default_events[$ "enter"];
	
	/// @ignore
	__default_events_keys = variable_struct_get_names(__default_events);
	
	/// @ignore time the current state has been active for in microseconds
	__time = get_timer();
	
	#endregion
	
	
	#region METHODS

	/// @param {real} state id
	/// @param {struct} state struct
	static add = function(_id, _state) 
	{
		if (__FASTSM_ENABLE_SAFETY) {
			if (!is_struct(_state) ) {
				throw(string("FastSM::Expected state struct, got {0} instead", typeof(_state) ) ); 
			}
			
			if (_id < 0 || _id >= __size) {
				throw(string("FastSM::Index [{0}] is out of bounds", _id) );
			}
			
			if (__FASTSM_ENABLE_WARNINGS && __states[_id] != undefined) {
				show_debug_message(
					"FastSM::State {0} has been defined already. The previous definition has been replaced.",
					_state[$ "name"] ?? "id: " + string(_id) + " <unknown name, please provide a state name>"
				);
			}
		}
		
		// Add state
		__states[_id] = _state;
		return self;
	}
	
	
	/// @param {real} trigger id
	/// @param {struct} trigger struct
	static add_trigger = function(_id, _trigger) {
		if (__FASTSM_ENABLE_SAFETY) {
			if (!is_struct(_trigger) ) {
				throw(string(
					"FastSM::Expected trigger struct, got {0} instead", typeof(_trigger)
				));
			}
			if (_trigger[$ "trigger"] == undefined || !is_callable(_trigger[$ "trigger"]) ) {
				throw(string(
					"FastSM::Expected trigger function, got {0} instead", typeof(_trigger[$ "trigger"])
				));
			}
			
			if (__FASTSM_ENABLE_WARNINGS && __triggers[_id] != undefined) {
				show_debug_message(
					"FastSM::Trigger {0} has been defined already. The previous definition has been replaced.",
					_trigger[$ "name"] ?? "id: " + string(_id) + " <unknown name, please provide a trigger name>"
				);
			}
		}
		
		__triggers[_id] = _trigger;
		return self;
	}
	
	
	/// @param {string} event name
	/// @param {function} default event callback
	static add_event = function(_event, _func = function() {}) 
	{
		if (__FASTSM_ENABLE_SAFETY) {
			if (!is_string(_event) ) {
				throw(
					string("FastSM::Expected event identifier (typeof string), got {0} instead", typeof(_event) ) 
				);
			}
			if (!is_callable(_func) ) {
				throw(
					string("FastSM::Expected event default function, got {0} instead", typeof(_func) )
				);
			}
		}
		
		__default_events[$ _event] = _func;
		return self;
	}
	
	
	/// @param {real} trigger id
	static process = function(_id) 
	{
		var _trigger = __triggers[_id];
		if (__FASTSM_ENABLE_SAFETY) {
			if (_trigger == undefined) {
				throw(
					string("FastSM::Trigger with id {0} has not been defined yet and cannot be triggered", _id) 
				);
			}
			
			if (_trigger[$ "__include_mask"] == undefined ||
				_trigger[$ "__exclude_mask"] == undefined ||
				_trigger[$ "__allow_mask"]	 == undefined ||
				_trigger[$ "__forbid_mask"]	 == undefined) {
				throw(string(
					"FastSM::Trigger {0} has not been built yet and cannot be triggered.", 
					_trigger[$ "name"] ?? "id: " + string(_id) + " <unknown name, please provide a trigger name>"
				) );
			}
			
			if (__FASTSM_ENABLE_WARNINGS) {
				if ((_trigger[$ "__include_mask"] == 0x00 && _trigger[$ "__allow_mask"] == 0x00) ||
					_trigger[$ "__forbid_mask"]   == 0x7FFFFFFFFFFFFFFF || 
					_trigger[$ "__exclude_mask"]  == 0x7FFFFFFFFFFFFFFF) {
					show_debug_message(
						"FastSM::Trigger {0} is invalid and will never be triggered.",
						_trigger[$ "name"] ?? "id: " + string(_id) + " <unknown name, please provide a trigger name>"
					);
				}
			}
		}
		
		if (__state_active == 0) exit;
		
		var _result = undefined;
		var _state  = __states[__state_active];
		
		if ((1 << __state_active) & _trigger[$ "__allow_mask"]) {
			_result = _trigger[$ "trigger"](_state);
		} else {
			var _mask = _state[$ "__mask"]
			if ((1 << __state_active) & _trigger[$ "__forbid_mask"] || _trigger[$ "__exclude_mask"] & _mask) exit;
			
			if (_trigger[$ "__include_mask"] & _mask) {
				_result = _trigger[$ "trigger"](_state);
			}
		}
		
		if (!_result) exit;
		change(_result);
	}
	
	
	/// @param {real} state id
	static change = function(_id) 
	{
		var _next_state    = __states[_id];
		var _current_state = __states[__state_active];
		
		if (__FASTSM_ENABLE_SAFETY) {
			if (_id < 0 || _id >= __size)   {
				throw(string("FastSM::Index [{0}] is out of bounds", _id) );
			}
			if (__states[_id] == undefined) {
				throw(string(
					"FastSM::State [{0}] has not been defined yet", 
					_next_state[$ "name"] ??  "<unknown name, please provide a state name>"
				));
			}
			
			if (__FASTSM_ENABLE_WARNINGS && _id == 0) {
				show_debug_message("FastSM::Trying to change to internal state\n This is not recommended.");
			}
		}
		
		/// @param this
		/// @param to
		_current_state[$ "leave"](_current_state, _next_state);
		
		__time = get_timer();
		__state_active = _id;
		
		var _previous_state = _current_state;
		var _current_state  = __states[__state_active];
		
		/// @param this
		/// @param before
		_current_state[$ "enter"](_current_state, _previous_state);
		var _current_state = __states[__state_active]; // Can change
		
		var i = 0; repeat(array_length(__default_events_keys) ) {
			var _key = __default_events_keys[i];
			self[$ _key] = _current_state[$ _key];
			i = i + 1;
		}
		
	}
	
	
	/// @param {real, array} tags to match
	/// @returns {real} match mask
	static has_tag = function(_tags) 
	{
		_tags ??= noone;
		_tags = is_array(_tags) ? _tags : [_tags];
		
		var _mask = 0x00;
		if (_tags[0] == noone) {
			_mask = 0x00;
		}
		else if (_tags[0] == all) {
			_mask = 0x7FFFFFFFFFFFFFFF;
		} else {
			var i = 0; repeat(array_length(_tags) ) {
				_mask += 0x01<<(_tags[i]);
				i = i + 1;
			}
		}
		
		return (_mask & __states[__state_active][$ "__mask"])
	}
	
	
	/// @desc Return the active state
	static get_current = function() 
	{
		static dcurrent = {
			name: "name", enter: function() {}, leave: function() {}
		}
		return is_struct(dcurrent) ? __states[__state_active] : dcurrent ;
	}
	
	
	/// @returns {real} current active state time in microseconds
	static get_time  = function() 
	{
	return (get_timer() - __time);
	}
	
	
	/// @param {real}   state_id
	/// @param {string} event_key
	/// @return {function}
	static get_event = function(_state_id, _name)
	{
		return (__states[_state_id] [$ _name]);
	}
	
	
	/// @param {real} state id
	static start = function(_id) 
	{
		__time = get_timer();
		__state_active = _id;
		var _active;
		if (__FASTSM_ENABLE_SAFETY) {
			if (_id < 0 || _id >= __size) {
				throw(string("FastSM::Index [{0}] is out of bounds", _id) );
			}
			
			_active = __states[__state_active];
			if (_active == undefined) {
				throw(string(
					"State [{0}] has not been defined yet", 
					_active[$ "name"] ??  "<unknown name, please provide a state name>"
				) );
			}
			
			if (__FASTSM_ENABLE_WARNINGS && _id == 0) {
				show_debug_message("FastSM::Trying to change to internal state\n This is not recommended.");
			}
		}

		_active = __states[__state_active];
		_active[$ "enter"](); // The first enter "this" is undefined
		_active = __states[__state_active]; // Can change
		
		var i=0, _key;
		repeat(array_length(__default_events_keys) ) {
			_key = __default_events_keys[i];
			self[$ _key] = _active[$ _key];
			i = i + 1;
		}
	}
	
	
	/// @returns {Struct.FastSM} self
	static build = function() 
	{
		// Update
		__default_events_keys = variable_struct_get_names(__default_events);
		
		//we skip state 0 since it only exists for technical reasons
		var i=1, j=0;
		
		repeat(__size - 1) {
			#region build states
			var _state = __states[i];
			
			// -- Errors
			if (__FASTSM_ENABLE_SAFETY) {
				if (__FASTSM_ENABLE_WARNINGS && _state == undefined) {
					show_debug_message(
						"FastSM::State with id [{0}] has not been defined yet and cannot be built. Skipping.", i
					);
					i = i + 1;
					continue;
				}
				if (__FASTSM_ENABLE_LOGGING) {
					show_debug_message(
						"FastSM BUILDING:: State {0}", 
						_state[$ _name] ?? "id: " + string(i) + "<unknown name, please provide a state name>"
					);
				}
			}
			
			var _mask  = 0x00;
			
			_state[$ "tags"] ??= noone;
			_state[$ "tags"] = is_array(_state[$ "tags"]) ? _state[$ "tags"] : [_state[$ "tags"]];
			var _tags = _state[$ "tags"];
			
			mask = 0x00;
			if (_tags[0] == noone) {
				_mask = 0x00;
			}
			else if (_tags[0] == all) {
				_mask = 0x7FFFFFFFFFFFFFFF;
			} else {
				var i = 0; repeat(array_length(_tags) ) {
					_mask += 0x01<<(_tags[i]);
					i = i + 1;
				}
			}
			_state[$ "__mask"] = _mask;
			
			j = 0; repeat(array_length(__default_events_keys) ) {;
				var _event = __default_events_keys[j];
				var _fn    = _state[$ _event] ?? __default_events[$ _event];

				_state[$ _event] = method(__owner, _fn);
				j = j + 1;
			}
			
			// Re-assign?
			__states[i] = _state;
			i = i + 1;
			#endregion
		}
		
		i = 0; repeat(__trigger_count) {
			#region build triggers
			var _trigger = __triggers[i];
			
			if (__FASTSM_ENABLE_SAFETY) {
				if (__FASTSM_ENABLE_WARNINGS && _trigger == undefined) {
					show_debug_message("FastSM::Trigger with id {0} has has not been defined yet and cannot be built. Skipping.", i);
					i = i + 1;
					continue;
				}
				if (__FASTSM_ENABLE_LOGGING) {
					show_debug_message(
					"FastSM BUILDING::Trigger {0}", 
						_trigger[$ "name"] ?? "id: " + string(i) + " <unknown name, please provide a trigger name>"
					);
				}
			}

			var _include = [];
			var _exclude = [];
			
			_trigger[$ "include"] ??= noone 
			if (!is_array(_trigger[$ "include"])) {
				_trigger[$ "include"] = [_trigger[$ "include"]];
			}
			_include = _trigger[$ "include"]; 
			
			_trigger[$ "exclude"] ??= noone 
			if (!is_array(_trigger[$ "exclude"])) {
				_trigger[$ "exclude"] = [_trigger[$ "exclude"]];
			}
			_exclude = _trigger[$ "exclude"]; 
			
			var _include_mask = 0x00;
			if (_include[0] == noone) {
				_include_mask = 0x00;
			}
			else if (_include[0] == all) {
				_include_mask = 0x7FFFFFFFFFFFFFFF;
			} else {
				j = 0; repeat(array_length(_include)) {
					_include_mask += 0x01<<(_include[j])
					j = j + 1;
				}
			}
			
			var _exclude_mask = 0x00;
			if (_exclude[0] == noone) {
				_exclude_mask = 0x00;
			}
			else if (_exclude[0] == all) {
				_exclude_mask = 0x7FFFFFFFFFFFFFFF;
			} else {
				j = 0; repeat(array_length(_exclude) ) {
					_exclude_mask += 0x01<<(_exclude[j] );
					j = j + 1;
				}
			}
			
			_trigger[$ "__include_mask"] = _include_mask;
			_trigger[$ "__exclude_mask"] = _exclude_mask;
			
			var _allow = [];
			var _forbid = [];
			
			_trigger[$ "allow"] ??= noone 
			if (!is_array(_trigger[$ "allow"])) {
				_trigger[$ "allow"] = [_trigger[$ "allow"]];
			}
			_allow = _trigger[$ "allow"]; 
			
			_trigger[$ "forbid"] ??= noone 
			if (!is_array(_trigger[$ "forbid"])) {
				_trigger[$ "forbid"] = [_trigger[$ "forbid"]];
			}
			_forbid = _trigger[$ "forbid"]; 
			
			var _allow_mask = 0x00;
			if (_allow[0] == noone) {
				_allow_mask = 0x00;
			}
			else if (_allow[0] == all) {
				_allow_mask = 0x7FFFFFFFFFFFFFFF;
			} else {
				j = 0; repeat(array_length(_allow) ) {
					_allow_mask += 0x01<<(_allow[i] );
					j = j + 1;
				}
			}
			
			var _forbid_mask = 0x00;
			if (_forbid[0] == noone) {
				_forbid_mask = 0x00;
			}
			else if (_forbid[0] == all) {
				_forbid_mask = 0x7FFFFFFFFFFFFFFF;
			} else {
				j = 0; repeat(array_length(_forbid) ) {
					_forbid_mask += 0x01<<(_forbid[j] );
					j = j + 1;
				}
			}
	
			_trigger[$ "__allow_mask"]   = _allow_mask;
			_trigger[$ "__forbid_mask"]  = _forbid_mask;
			_trigger[$ "trigger"] = method( __owner, _trigger[$ "trigger"]);
			
			i = i + 1;
			#endregion
		}
		
		return self;
	}
	
	#endregion
}