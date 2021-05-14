uses GraphABC, ABCObjects;

begin
  SetFontName('Thintel');
  
  
  var s := 'Это самонабираемое сообщение!' + NewLine + 'И далее...' + NewLine + 'Дорогой путник, дорога наверняка была тяжелой?';
  var t := TextABC.Create(64, 150, 14, '', clBlack);
  t.FontSize := 28;
  var sp := new System.Media.SoundPlayer('beep.wav');
  sp.Load();
  Sleep(2000);
  for var i:=1 to s.Length do
  begin
    t.Text += s[i];
    //sp.Play();
    Sleep(64);
  end;
  sp.Stop();
end.