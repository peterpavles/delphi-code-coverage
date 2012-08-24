(* ************************************************************ *)
(* Delphi Code Coverage *)
(* *)
(* A quick hack of a Code Coverage Tool for Delphi 2010 *)
(* by Christer Fahlgren and Nick Ring *)
(* ************************************************************ *)
(* Licensed under Mozilla Public License 1.1 *)
(* ************************************************************ *)

unit XMLCoverageReport;

interface

{$INCLUDE CodeCoverage.inc}

uses
  I_Report,
  I_CoverageStats,
  JclSimpleXml,
  I_CoverageConfiguration,
  ClassInfoUnit, I_LogManager;

type
  TXMLCoverageReport = class(TInterfacedObject, IReport)
  private
    FCoverageConfiguration: ICoverageConfiguration;

    procedure WriteAllStats(const AJclSimpleXMLElem: TJclSimpleXMLElem;
      const ACoverageStats: ICoverageStats;
      const AModuleList: TModuleList);
    procedure WriteModuleStats(const AJclSimpleXMLElem: TJclSimpleXMLElem;
      const AModule: TModuleInfo);
    procedure WriteClassStats(const AJclSimpleXMLElem: TJclSimpleXMLElem;
      const AClass: TClassInfo);
    procedure WriteMethodStats(const AJclSimpleXMLElem: TJclSimpleXMLElem;
      const AMethod: TProcedureInfo);
  public
    constructor Create(const ACoverageConfiguration: ICoverageConfiguration);

    procedure Generate(const ACoverage: ICoverageStats;
      const AModuleInfoList: TModuleList; logMgr: ILogManager);
  end;

implementation

uses
  SysUtils,
  JclFileUtils,
  Generics.Collections;

{ TXMLCoverageReport }

procedure TXMLCoverageReport.Generate(const ACoverage: ICoverageStats;
  const AModuleInfoList: TModuleList; logMgr: ILogManager);
var
  ModuleIter: TEnumerator<TModuleInfo>;
  ClassIter: TEnumerator<TClassInfo>;
  MethodIter: TEnumerator<TProcedureInfo>;
  JclSimpleXml: TJclSimpleXML;
  JclSimpleXMLElemStats: TJclSimpleXMLElem; // Pointer
  JclSimpleXMLElemPackage: TJclSimpleXMLElem; // Pointer
  JclSimpleXMLElemSrcFile: TJclSimpleXMLElem; // Pointer
  JclSimpleXMLElemAll: TJclSimpleXMLElem; // Pointer
  JclSimpleXMLElemClass: TJclSimpleXMLElem; // Pointer
  JclSimpleXMLElemMethod: TJclSimpleXMLElem; // Pointer
begin
logMgr.Log('Generating xml coverage report');
  JclSimpleXml := nil;
  try
    JclSimpleXml := TJclSimpleXML.Create;

    JclSimpleXml.Root.Name := 'report';

    JclSimpleXMLElemStats := JclSimpleXml.Root.Items.Add('stats');
    JclSimpleXMLElemStats.Items.Add('packages').Properties.Add('value',
      AModuleInfoList.GetCount());
    JclSimpleXMLElemStats.Items.Add('classes').Properties.Add('value',
      AModuleInfoList.GetTotalClassCount());
    JclSimpleXMLElemStats.Items.Add('methods').Properties.Add('value',
      AModuleInfoList.GetTotalMethodCount());

    JclSimpleXMLElemStats.Items.Add('srcfiles').Properties.Add('value',
      AModuleInfoList.GetCount());
    JclSimpleXMLElemStats.Items.Add('srclines').Properties.Add('value',
      AModuleInfoList.GetTotalLineCount());

    JclSimpleXMLElemStats.Items.Add('totallines').Properties.Add('value',
      ACoverage.LineCount);
    JclSimpleXMLElemStats.Items.Add('coveredlines').Properties.Add('value',
      ACoverage.CoveredLineCount);
    JclSimpleXMLElemStats.Items.Add('coveredpercent').Properties.Add('value',
      ACoverage.PercentCovered);

    JclSimpleXMLElemAll := JclSimpleXml.Root.Items.Add('data').Items.Add('all');
    JclSimpleXMLElemAll.Properties.Add('name', 'all classes');
    WriteAllStats(JclSimpleXMLElemAll, ACoverage, AModuleInfoList);
    ModuleIter := AModuleInfoList.GetModuleIterator;
    try
      while (ModuleIter.moveNext()) do
      begin

        JclSimpleXMLElemPackage := JclSimpleXMLElemAll.Items.Add('package');
        JclSimpleXMLElemPackage.Properties.Add('name',
          ModuleIter.Current.getModuleName);
        WriteModuleStats(JclSimpleXMLElemPackage, ModuleIter.Current);
        JclSimpleXMLElemSrcFile := JclSimpleXMLElemPackage.Items.Add('srcfile');
        JclSimpleXMLElemSrcFile.Properties.Add('name',
          ModuleIter.Current.getModuleFileName);
        WriteModuleStats(JclSimpleXMLElemSrcFile, ModuleIter.Current);
        ClassIter := ModuleIter.Current.GetClassIterator;
        try
          while (ClassIter.moveNext()) do
          begin

            JclSimpleXMLElemClass := JclSimpleXMLElemSrcFile.Items.Add('class');
            JclSimpleXMLElemClass.Properties.Add('name',
              ClassIter.Current.getClassName);
            WriteClassStats(JclSimpleXMLElemClass, ClassIter.Current);
            MethodIter := ClassIter.Current.GetProcedureIterator;
            try
              while (MethodIter.moveNext()) do
              begin
                JclSimpleXMLElemMethod := JclSimpleXMLElemClass.Items.Add('method');
                JclSimpleXMLElemMethod.Properties.Add('name',
                  MethodIter.Current.getName);
                WriteMethodStats(JclSimpleXMLElemMethod, MethodIter.Current);
              end;
            finally
              MethodIter.Free;
            end;
          end;
        finally
          ClassIter.Free;
        end;
      end;
    finally
      ModuleIter.Free;
    end;

    JclSimpleXml.SaveToFile(PathAppend(FCoverageConfiguration.OutputDir,
        'CodeCoverage_Summary.xml'));
  finally
    JclSimpleXml.Free;
  end;
end;

constructor TXMLCoverageReport.Create(const ACoverageConfiguration
    : ICoverageConfiguration);
begin
  inherited Create;
  FCoverageConfiguration := ACoverageConfiguration;
end;

function getCoverageStringValue(covered, total: Integer): String;
var
  Percent: Integer;
begin
  if Total = 0 then
    Percent := 0
  else
    Percent := Round(covered * 100 / total);

  Result := IntToStr(Percent) + '%   (' + IntToStr(covered) + '/' +
    IntToStr(total) + ')';
end;

procedure TXMLCoverageReport.WriteModuleStats
  (const AJclSimpleXMLElem: TJclSimpleXMLElem; const AModule: TModuleInfo);
var
  JclSimpleXMLElemCoverage: TJclSimpleXMLElem;
begin
  JclSimpleXMLElemCoverage := AJclSimpleXMLElem.Items.Add('coverage');
  JclSimpleXMLElemCoverage.Properties.Add('type', 'class, %');
  JclSimpleXMLElemCoverage.Properties.Add('value',
    getCoverageStringValue(AModule.GetCoveredClassCount(),
      AModule.GetClassCount()));

  JclSimpleXMLElemCoverage := AJclSimpleXMLElem.Items.Add('coverage');
  JclSimpleXMLElemCoverage.Properties.Add('type', 'method, %');
  JclSimpleXMLElemCoverage.Properties.Add('value',
    getCoverageStringValue(AModule.GetCoveredMethodCount(),
      AModule.GetMethodCount()));

  JclSimpleXMLElemCoverage := AJclSimpleXMLElem.Items.Add('coverage');
  JclSimpleXMLElemCoverage.Properties.Add('type', 'block, %');
  JclSimpleXMLElemCoverage.Properties.Add('value',
    getCoverageStringValue(AModule.GetTotalCoveredLineCount(),
      AModule.GetTotalLineCount()));

  JclSimpleXMLElemCoverage := AJclSimpleXMLElem.Items.Add('coverage');
  JclSimpleXMLElemCoverage.Properties.Add('type', 'line, %');
  JclSimpleXMLElemCoverage.Properties.Add('value',
    getCoverageStringValue(AModule.GetTotalCoveredLineCount(),
      AModule.GetTotalLineCount()));
end;

procedure TXMLCoverageReport.WriteClassStats
  (const AJclSimpleXMLElem: TJclSimpleXMLElem; const AClass: TClassInfo);
var
  JclSimpleXMLElemCoverage: TJclSimpleXMLElem;
begin
  JclSimpleXMLElemCoverage := AJclSimpleXMLElem.Items.Add('coverage');
  JclSimpleXMLElemCoverage.Properties.Add('type', 'class, %');
  if (AClass.GetIsCovered) then
  begin
    JclSimpleXMLElemCoverage.Properties.Add('value',
      getCoverageStringValue(1, 1));

  end
  else
  begin
    JclSimpleXMLElemCoverage.Properties.Add('value',
      getCoverageStringValue(0, 1));

  end;
  JclSimpleXMLElemCoverage := AJclSimpleXMLElem.Items.Add('coverage');
  JclSimpleXMLElemCoverage.Properties.Add('type', 'method, %');
  JclSimpleXMLElemCoverage.Properties.Add('value',
    getCoverageStringValue(AClass.GetCoveredProcedureCount(),
      AClass.GetProcedureCount()));

  JclSimpleXMLElemCoverage := AJclSimpleXMLElem.Items.Add('coverage');
  JclSimpleXMLElemCoverage.Properties.Add('type', 'block, %');
  JclSimpleXMLElemCoverage.Properties.Add('value',
    getCoverageStringValue(AClass.GetTotalCoveredLineCount(),
      AClass.GetTotalLineCount()));

  JclSimpleXMLElemCoverage := AJclSimpleXMLElem.Items.Add('coverage');
  JclSimpleXMLElemCoverage.Properties.Add('type', 'line, %');
  JclSimpleXMLElemCoverage.Properties.Add('value',
    getCoverageStringValue(AClass.GetTotalCoveredLineCount(),
      AClass.GetTotalLineCount()));
end;

procedure TXMLCoverageReport.WriteMethodStats
  (const AJclSimpleXMLElem: TJclSimpleXMLElem; const AMethod: TProcedureInfo);
var
  JclSimpleXMLElemCoverage: TJclSimpleXMLElem;
  covered: Integer;
begin

  JclSimpleXMLElemCoverage := AJclSimpleXMLElem.Items.Add('coverage');
  JclSimpleXMLElemCoverage.Properties.Add('type', 'method, %');
  if (AMethod.GetCoverageInPercent > 0) then
    covered := 1
  else
    covered := 0;

  JclSimpleXMLElemCoverage.Properties.Add('value',
    getCoverageStringValue(covered, 1));

  JclSimpleXMLElemCoverage := AJclSimpleXMLElem.Items.Add('coverage');
  JclSimpleXMLElemCoverage.Properties.Add('type', 'block, %');
  JclSimpleXMLElemCoverage.Properties.Add('value',
    getCoverageStringValue(AMethod.GetCoveredLineCount(), AMethod.GetLineCount()));

  JclSimpleXMLElemCoverage := AJclSimpleXMLElem.Items.Add('coverage');
  JclSimpleXMLElemCoverage.Properties.Add('type', 'line, %');
  JclSimpleXMLElemCoverage.Properties.Add('value',
    getCoverageStringValue(AMethod.GetCoveredLineCount(), AMethod.GetLineCount()));
end;

procedure TXMLCoverageReport.WriteAllStats
  (const AJclSimpleXMLElem: TJclSimpleXMLElem;
  const ACoverageStats: ICoverageStats; const AModuleList: TModuleList);
var
  JclSimpleXMLElemCoverage: TJclSimpleXMLElem;
begin
  JclSimpleXMLElemCoverage := AJclSimpleXMLElem.Items.Add('coverage');
  JclSimpleXMLElemCoverage.Properties.Add('type', 'class, %');
  JclSimpleXMLElemCoverage.Properties.Add('value',
    getCoverageStringValue(AModuleList.GetTotalCoveredClassCount(),
      AModuleList.GetTotalClassCount()));

  JclSimpleXMLElemCoverage := AJclSimpleXMLElem.Items.Add('coverage');
  JclSimpleXMLElemCoverage.Properties.Add('type', 'method, %');
  JclSimpleXMLElemCoverage.Properties.Add('value',
    getCoverageStringValue(AModuleList.GetTotalCoveredMethodCount(),
      AModuleList.GetTotalMethodCount()));

  JclSimpleXMLElemCoverage := AJclSimpleXMLElem.Items.Add('coverage');
  JclSimpleXMLElemCoverage.Properties.Add('type', 'block, %');
  JclSimpleXMLElemCoverage.Properties.Add('value',
    getCoverageStringValue(AModuleList.GetTotalCoveredLineCount(),
      AModuleList.GetTotalLineCount()));

  JclSimpleXMLElemCoverage := AJclSimpleXMLElem.Items.Add('coverage');
  JclSimpleXMLElemCoverage.Properties.Add('type', 'line, %');
  JclSimpleXMLElemCoverage.Properties.Add('value',
    getCoverageStringValue(AModuleList.GetTotalCoveredLineCount(),
      AModuleList.GetTotalLineCount()));

end;

end.
