const
  yymaxdepth = 1024;

var
  yychar:  integer;

var
  yyflag:    (yyfnone, yyfaccept, yyfabort, yyferror, yyfdone);
  yyerrflag: integer;

procedure yyclearin;
begin
  yychar := -1;
end;

procedure yy_done;
begin
  yyflag := yyfdone;
end;

procedure yyaccept;
begin
  yyflag := yyfaccept;
end;

procedure yyabort;
begin
  yyflag := yyfabort;
end;

procedure yyerrlab;
begin
  yyflag := yyferror;
end;

procedure yyerrok;
begin
  yyerrflag := 0;
end;
