library JSONParser;
{$reference System.Web.Extensions.dll}
uses System.Collections.Generic, System.Web.Script.Serialization;
type
Dic = Dictionary<string, object>;
ObjArr = array of object;

JSONFile = class
  private
  data:Dic;
  
  public
  constructor Create(path:string);
  begin
    var json := ReadAllText(path);
    var jss := new JavaScriptSerializer();
    data := jss.DeserializeObject(json) as Dic;
  end;
  
  function GetValue(key:string):Object;
  begin
    var t := data;
    var tempKey:string;
    
    for var i:= 1 to key.Length do begin
      if (key[i]<>'.') then
        tempKey+=key[i]
      else begin
        t := t[tempKey] as Dic;
        tempKey:='';
      end;
    end;
    Result := t[tempKey];
  end;
end;
end.