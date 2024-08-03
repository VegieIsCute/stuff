repeat task.wait() until game:IsLoaded() -- precaution

--[[ Variables ]]--
local specialInfo = {
	MeshPart = { "PhysicsData", "InitialSize" },
	UnionOperation = { "AssetId", "ChildData", "FormFactor", "InitialSize", "MeshData", "PhysicsData" },
	Terrain = { "SmoothGrid", "MaterialColors" },
};

local renv = getrenv();
local genv = getgenv();

local _getreg = clonefunction(getreg);
local _gettenv = clonefunction(gettenv);
local _getinfo = clonefunction(debug.getinfo);
local _gethiddenproperty = clonefunction(gethiddenproperty);
local _getconnections = clonefunction(getconnections);
local _getsenv = clonefunction(getsenv);
local _newcclosure = clonefunction(newcclosure);
local _getthreadidentity = clonefunction(getthreadidentity);
local _setthreadidentity = clonefunction(setthreadidentity);
local _setreadonly = clonefunction(setreadonly);
local _isreadonly = clonefunction(isreadonly);

local _assert = clonefunction(renv.assert);
local _type = clonefunction(renv.type);
local _typeof = clonefunction(renv.typeof);
local _stringformat = clonefunction(renv.string.format);
local _setmetatable = clonefunction(renv.setmetatable);
local _rawset = clonefunction(renv.rawset);
local _getfenv = clonefunction(renv.getfenv);
local _setfenv = clonefunction(renv.setfenv);

--[[ Functions ]]--

genv.getallthreads = _newcclosure(function()
	local threads = {};
    for i, v in _getreg() do
		if _type(v) == "thread" then
			threads[#threads + 1] = v;
		end
	end
	return threads;
end);

genv.getcurrentline = _newcclosure(function(level)
	_assert(level == nil or _type(level) == "number", "invalid argument #1 to 'getcurrentline' (number or nil expected)");
	return _getinfo((level or 0) + 3).currentline;
end);

genv.getscriptenvs = _newcclosure(function()
    local envs = {};
    for i, v in _getreg() do
        if _type(v) == "thread" then
            local env = _gettenv(v);
            local scr = env.script;
            if scr and envs[scr] == nil then
                envs[scr] = env;
            end
        end
    end
    return envs;
end);

genv.getspecialinfo = _newcclosure(function(inst)
    local classInfo = _assert(_typeof(inst) == "Instance" and specialInfo[inst.ClassName], "invalid argument #1 to 'getspecialinfo' (MeshPart or UnionOperation or Terrain expected)");
	local instInfo = {};
	for i, v in classInfo do
		instInfo[v] = _gethiddenproperty(inst, v);
	end
	return instInfo;
end);

genv.firesignal = _newcclosure(function(signal, ...)
    _assert(_typeof(signal) == "RBXScriptSignal", _stringformat("invalid argument #1 to 'firesignal' (RBXScriptSignal expected, got %s)", _typeof(signal)));
    for _, v in _getconnections(signal) do
        v:Fire(...);
    end
end);

genv.emulate_call = _newcclosure(function(func, targetScript, ...)
    _assert(_typeof(func) == "function", _stringformat("invalid argument #1 to 'emulate_call' (function expected, got %s)", _typeof(func)));
    _assert(_typeof(targetScript) == "Instance" and (targetScript.ClassName == "LocalScript" or targetScript.ClassName == "ModuleScript"), "invalid argument #2 to 'emulate_call' (LocalScript or ModuleScript expected)");

    local scriptEnv = _getsenv(targetScript);

    local env = _setmetatable({}, {
        __index = _newcclosure(function(self, idx)
            return scriptEnv[idx];
        end),
        __newindex = _newcclosure(function(self, idx, newval)
            _rawset(self, idx, newval);
        end),
        __metatable = "This metatable is locked."
    });

    return (_newcclosure(function(...)
        local realEnv = _getfenv(1);
        local oldIdentity = _getthreadidentity();
        _setthreadidentity(2);
        _setfenv(1, env);
        local ret = func(...);
        _setfenv(1, realEnv);
        _setthreadidentity(oldIdentity);
        return ret;
    end))(...);
end);

genv.makereadonly = _newcclosure(function(table)
    _assert(_typeof(table) == "table", _stringformat("invalid argument #1 to 'makereadonly' (table expected, got %s)", _typeof(table)));
    return _setreadonly(table, true);
end);

genv.makewriteable = _newcclosure(function(table)
    _assert(_typeof(table) == "table", _stringformat("invalid argument #1 to 'makewriteable' (table expected, got %s)", _typeof(table)));
    return _setreadonly(table, false);
end);

genv.iswriteable = _newcclosure(function(table)
    _assert(_typeof(table) == "table", _stringformat("invalid argument #1 to 'iswriteable' (table expected, got %s)", _typeof(table)));
    return not _isreadonly(table);
end);

genv.getmodules = clonefunction(getloadedmodules);

local debug_is_readonly = _isreadonly(genv.debug);
_setreadonly(genv.debug, false)
genv.debug.validlevel = genv.debug.isvalidlevel
_setreadonly(genv.debug, debug_is_readonly)

genv.rconsoleshow = _newcclosure(function() end);
genv.rconsolename = _newcclosure(function() end);
genv.rconsoleinput = _newcclosure(function() return "" end);
genv.rconsoleprint = _newcclosure(function() end);
genv.rconsolewarn = _newcclosure(function() end);
genv.rconsoleerror = _newcclosure(function() end);
genv.rconsoleinfo = _newcclosure(function() end);

--[[ Aliases ]]--

local aliasData = {
    --[getclipboard] = { "fromclipboard" },
    --[executeclipboard] = { "execclipboard" },
    [setclipboard] = { "setrbxclipboard", "toclipboard" },
    [hookfunction] = { "hookfunc", "replaceclosure", "replacefunction", "replacefunc", "detourfunction", "replacecclosure", "detour_function" },
    --[isfunctionhooked] = { "ishooked" },
    --[restorefunction] = { "restorefunc", "restoreclosure" },
    [clonefunction] = { "clonefunc" },
    [makewriteable] = { "make_writeable" },
    [makereadonly] = { "make_readonly" },
    [getinstances] = { "get_instances" },
    [getscripts] = { "get_scripts" },
    [getmodules] = { "get_modules" },
    [getloadedmodules] = { "get_loaded_modules" },
    [getnilinstances] = { "get_nil_instances" },
    [getcallingscript] = { "get_calling_script", "getscriptcaller", "getcaller" },
    [getallthreads] = { "get_all_threads" },
    [getgc] = { "get_gc_objects" },
    [gettenv] = { "getstateenv" },
    [getnamecallmethod] = { "get_namecall_method" },
    [setnamecallmethod] = { "set_namecall_method" },
    [debug.getupvalue] = { "getupvalue" },
    [debug.getupvalues] = { "getupvalues" },
    [debug.setupvalue] = { "setupvalue" },
    [debug.getconstant] = { "getconstant" },
    [debug.getconstants] = { "getconstants" },
    [debug.setconstant] = { "setconstant" },
    [debug.getproto] = { "getproto" },
    [debug.getprotos] = { "getprotos" },
    [debug.getstack] = { "getstack" },
    [debug.setstack] = { "setstack" },
    [debug.getinfo] = { "getinfo" },
    [debug.validlevel] = { "validlevel", "isvalidlevel" },
    [islclosure] = { "is_l_closure" },
    [iscclosure] = { "is_c_closure" },
    [isourclosure] = { "isexecutorclosure", "is_our_closure", "is_executor_closure", "is_krnl_closure", "is_fluxus_closure", "isfluxusclosure", "is_fluxus_function", "isfluxusfunction", "is_protosmasher_closure","checkclosure", "issynapsefunction", "is_synapse_function" },
    [getscriptclosure] = { "getscriptfunction", "get_script_function" },
    [getscriptbytecode] = { "dumpstring" },
    [emulate_call] = { "secure_call", "securecall" },
    [queueonteleport] = { "queue_on_teleport" },
    --[clearteleportqueue] = { "clear_teleport_queue" },
    [request] = { "http_request" },
    [getsenv] = { "getmenv" },
    [getfpscap] = { "get_fps_cap" },
    [identifyexecutor] = { "getexecutorname" },
    [getcustomasset] = { "getsynasset" },
    [base64_encode] = { "base64encode" },
    [base64_decode] = { "base64decode" },
    [isrbxactive] = { "isgameactive", "iswindowactive" },
    [delfile] = { "deletefile" },
    [delfolder] = { "deletefolder" },
    [getthreadidentity] = { "getidentity", "getcontext", "getthreadcontext", "get_thread_context", "get_thread_identity" },
    [setthreadidentity] = { "setidentity", "setcontext", "setthreadcontext", "set_thread_context", "set_thread_identity" },
    [iswriteable] = { "iswritable" },
    [makewriteable] = { "makewritable" },
    [rconsoleshow] = { "rconsolecreate", "consolecreate" },
    [rconsolename] = { "consolesettitle" },
    [rconsoleinput] = { "consoleinput" },
    [rconsoleprint] = { "logprint", "consoleprint", "printuiconsole", "printdebug" },
    [rconsolewarn] = { "logwarn", "consolewarn", "warnuiconsole", "printuiwarn" },
    [rconsoleerror] = { "logerror", "consoleerror", "erroruiconsole", "printuierror", "rconsoleerr", "consoleerr" },
    [rconsoleinfo] = { "loginfo", "consoleinfo", "infouiconsole" }
};

for func, aliases in aliasData do
    for idx = 1, #aliases do
        genv[aliases[idx]] = func;
    end
end
