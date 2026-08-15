// Copyright (c) 2010-2026 Zhang Weidong <zwd@funlang.org>
// SPDX-License-Identifier: MIT

use 'lib-os.fun';

var PROV_RSA_AES = 24;
var CALG_MD5     = 32771;
var CALG_Sha1    = 32772;
var CALG_Sha256  = 32780;
var CALG_Sha384  = 32781;
var CALG_Sha512  = 32782;
var CALG_AES_128 = 0x0000660e;
var CRYPT_EXPORTABLE = 0x00000001;
var KP_IV        = 1;
var KP_MODE      = 4;
var KP_PADDING   = 3;
var ZERO_PADDING = 3;
var CRYPT_MODE_CBC = 1;
var PLAINTEXTKEYBLOB     = 0x8;
var SYMMETRICWRAPKEYBLOB = 0xB;
var HP_HASHVAL   = 2;
var HP_HASHSIZE  = 4;

var AA        = 'advapi32';
var CrAcquire = AA.getapi('CryptAcquireContext', 'piiii:i');
var CrCreate  = AA.getapi('CryptCreateHash',     'iiiip:i');
var CrHash    = AA.getapi('CryptHashData',       'iaii:i'); // 'r' ?
var CrGet     = AA.getapi('CryptGetHashParam',   'iippi:i');
var CrDestroy = AA.getapi('CryptDestroyHash',    'i:v');
var CrDelKey  = AA.getapi('CryptDestroyKey',     'i:v');
var CrRelease = AA.getapi('CryptReleaseContext', 'ii:v');
var CrKey     = AA.getapi('CryptDeriveKey',      'iiiip:i'); #*
    HCRYPTPROV hProv,
    ALG_ID Algid,
    HCRYPTHASH hBaseData,
    DWORD dwFlags,
    HCRYPTKEY *phKey #
var CrImKey   = AA.getapi('CryptImportKey',      'iaiiip:i'); #*
    HCRYPTPROV hProv,
    BYTE *pbData,
    DWORD dwDataLen,
    HCRYPTKEY hImpKey,
    DWORD dwFlags,
    HCRYPTKEY *phKey #
var CrExKey   = AA.getapi('CryptExportKey',      'iiiiap:i'); #*
    HCRYPTKEY hKey,
    HCRYPTKEY hExpKey,
    DWORD     dwBlobType,
    DWORD     dwFlags,
    BYTE      *pbData,
    DWORD     *pdwDataLen #
var CrSetKey  = AA.getapi('CryptSetKeyParam',    'iiai:i'); #*
    HCRYPTKEY hKey,
    DWORD dwParam,
    BYTE *pbData,
    DWORD dwFlags #
var CrEncrypt = AA.getapi('CryptEncrypt',        'iiiiapi:i'); #*
    HCRYPTKEY hKey,
    HCRYPTHASH hHash,
    BOOL Final,
    DWORD dwFlags,
    BYTE *pbData,
    DWORD *pdwDataLen,
    DWORD dwBufLen #
var CrDecrypt = AA.getapi('CryptDecrypt',        'iiiiap:i'); #*
    HCRYPTKEY hKey,
    HCRYPTHASH hHash,
    BOOL Final,
    DWORD dwFlags,
    BYTE *pbData,
    DWORD *pdwDataLen #
#*
?. 'Starting...';
?. Crypt('', CALG_MD5);
?. Crypt('', CALG_Sha1);
?. Crypt('', CALG_Sha256);
?. Crypt('', CALG_Sha384);
?. Crypt('', CALG_Sha512);
?. 'End.'; #

fun Crypt(msg, typ)
  result = nil;
  var hProv = 0;
  if CrAcquire(var hProv, 0, 0, PROV_RSA_AES, 0) then
    var hHash = 0;
    if CrCreate(hProv, typ, 0, 0, var hHash) then
      if CrHash(hHash, msg, msg.length(), 0) then
        var dwHashLen = 0;
        var dwCount   = 4;
        if CrGet(hHash, HP_HASHSIZE, var dwHashLen, dwCount, 0) then
          var s = ' '.x(dwHashLen); // Only ANSI
          if CrGet(hHash, HP_HASHVAL, s, dwHashLen, 0) then
            result = str2hex(s);
          end if;
        end if;
      end if;
      CrDestroy(hHash);
    end if;
    CrRelease(hProv, 0);
  end if;
  if result = nil then
    raise ShowLastError();
  end if;
end fun;

fun AES(msg, key, isDecode, args)
  result = nil;
  var hProv = 0;
  if CrAcquire(var hProv, 0, 0, PROV_RSA_AES, 0) then
    var hKey = 0; //key = hex2str('080200000E66000010000000855F356D6BCD47F20408855927E5F610');
    //key = hex2str('080200000E660000') & int2str(16) & key; //'c:\temp\admin\aes--%s.key'.format(1.time()*1).save(key);
    if CrImKey(hProv, key, key.length(), 0, 0, var hKey) or 1 then // or true then # Ìø¹ý CrImKey
      var hHash = 0;
      if hKey <> 0 or CrCreate(hProv, CALG_MD5, 0, 0, var hHash) then
        if hKey <> 0 or CrHash(hHash, key, key.length(), 0) then
          if hKey <> 0 or CrKey(hProv, CALG_AES_128, hHash, CRYPT_EXPORTABLE, var hKey) then //?. hKey;
            #*var s = ' '.x(1024); var i = 1024;
            CrExKey(hKey, 0, PLAINTEXTKEYBLOB, 0, s, var i); ##'c:\temp\admin\aes-%s.key'.format(1.time()*1).save(s.substr(len: i));
            if args = nil or args.mode = nil or CrSetKey(hKey, KP_MODE, int2str(args.mode), 0) then
              if args = nil or args.iv = nil or CrSetKey(hKey, KP_IV, args.iv, 0) then
                if args = nil or args.padding = nil or CrSetKey(hKey, KP_PADDING, int2str(args.padding), 0) then
                  var dwDataLen = msg.length();
                  var x = msg.x(4);
                  if isDecode then
                    if CrDecrypt(hKey, 0, true, 0, x, var dwDataLen) then //?. dwDataLen;
                      result = x.substr(len: dwDataLen);
                    end if;
                  else
                    if CrEncrypt(hKey, 0, true, 0, x, var dwDataLen, x.length()) then //?. dwDataLen;
                      result = x.substr(len: dwDataLen);
                    end if;
                  end if;
                end if;
              end if;
            end if;
          end if;
          CrDelKey(hKey);
        end if;
        CrDestroy(hHash);
      end if;
    end if;
    CrRelease(hProv, 0);
  end if;
  if result = nil then
    raise ShowLastError();
  end if;
end fun;
var Encode = AES;
var AES_CBC(msg, key, isDecode) = AES(msg, key, isDecode, new [mode: CRYPT_MODE_CBC, ivX: key, paddingX: ZERO_PADDING]);

fun RSA(msg, key, isDecode)
  result = nil;
  var hProv = 0;
  if CrAcquire(var hProv, 0, 0, 1 #*PROV_RSA_FULL#, 0) then
    var hKey = 0; //key = hex2str('');
    if CrImKey(hProv, key, key.length(), 0, 0, var hKey) then
      var dwDataLen = msg.length();
      var x = msg.x(4);
      if isDecode then
        if CrDecrypt(hKey, 0, true, 0, x, var dwDataLen) then //?. dwDataLen;
          result = x.substr(len: dwDataLen);
        end if;
      else
        if CrEncrypt(hKey, 0, true, 0, x, var dwDataLen, x.length()) then //?. dwDataLen;
          result = x.substr(len: dwDataLen);
        end if;
      end if;
      CrDelKey(hKey);
    end if;
    CrRelease(hProv, 0);
  end if;
  if result = nil then
    raise ShowLastError();
  end if;
end fun;
