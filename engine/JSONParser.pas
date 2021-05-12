library JSONParser;
{$reference System.Web.Extensions.dll}
uses System.Collections.Generic, System.Web.Script.Serialization;
type
Dic = Dictionary<string, object>;

JSONFile = class
  private
  data:Dic;
  path:string;
  jss:JavaScriptSerializer;
  
  public
  constructor Create(ppath:string);
  begin
    path := ppath;
    var json := ReadAllText(path, Encoding.UTF8);
    jss := new JavaScriptSerializer();
    data := jss.DeserializeObject(json) as Dic;
  end;
  
  function SetVal(a:Dic; n:integer; key:string; val:object):Dic;
  begin
    var tempKey := key.Split('.');
    if (n = tempKey.Length-1) then begin
      if not (a.ContainsKey(tempKey[n])) then
        a.Add(tempKey[n], val)
      else a[tempKey[n]]:=val;
      //writeln(a);
      Result := a;
    end
    else begin
      if not (a.ContainsKey(tempKey[n])) then
        a.Add(tempKey[n], new Dic());
      Result := SetVal(a[tempKey[n]] as Dic, n+1, key, val);
    end;
  end;
  
  {Нужна процедура создания => добавления нового значения в data
   Нужна процедура изменения уже текущего значения}
  procedure SetValue(key:string; val:Object);
  begin
    var tempKey := key.Split('.');
    if not (data.ContainsKey(tempKey[0])) then
      data.Add(tempKey[0], new Dic());
    data[tempKey[0]] := SetValue(data[tempKey[0]] as Dic, key, 1, val)
  end;
  
  function SetValue(t:Dic; key:string; n:integer; val:Object):Dic;
  begin
    var tempKey := key.Split('.');
    if (n = tempKey.Length-1) then begin
      if not (t.ContainsKey(tempKey[n])) then
        t.Add(tempKey[n], val)
      else
        t[tempKey[n]]:= val;
      Result := t;
    end
    else begin
      if not (t.ContainsKey(tempKey[n])) then
        t.Add(tempKey[n], new Dic());
      t[tempKey[n]] := SetValue(t[tempKey[n]] as Dic, key, n+1, val);
      Result := t;
    end;
  end;
  
  //Возвращает значение по указанному ключу
  function GetValue(key:string):Object;
  begin
    var t := data; 
    var tempKey := key.Split('.');
    for var i := 0 to tempKey.Length-1 do begin
      if i = tempKey.Length-1 then Result := t[tempKey[i]]
      else t := t[tempKey[i]] as Dic;
    end;
  end;
  
  //Сохраняет файл json
  procedure SaveFile();
  begin
    var json := jss.Serialize(data as Object);
    writeln(data);
    WriteAllText(path, json, Encoding.UTF8);
  end;
  
  //Сохраняет файл json по пути ppath
  procedure SaveFile(ppath:string);
  begin
    path := ppath;
    SaveFile();
  end;
end;
end.