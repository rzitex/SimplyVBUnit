VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
  Persistable = 0  'NotPersistable
  DataBindingBehavior = 0  'vbNone
  DataSourceBehavior  = 0  'vbNone
  MTSTransactionMode  = 0  'NotAnMTSObject
END
Attribute VB_Name = "AndFilter"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = True
' Copyright 2009 Kelly Ethridge
'
' Licensed under the Apache License, Version 2.0 (the "License");
' you may not use this file except in compliance with the License.
' You may obtain a copy of the License at
'
'     http://www.apache.org/licenses/LICENSE-2.0
'
' Unless required by applicable law or agreed to in writing, software
' distributed under the License is distributed on an "AS IS" BASIS,
' WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
' See the License for the specific language governing permissions and
' limitations under the License.
'
' Module: AndFilter
'
Option Explicit
Implements ITestFilter

Private mBase       As New TestFilterBase
Private mFilters    As New Collection


Public Sub Add(ByVal Filter As ITestFilter)
    mFilters.Add Filter
End Sub

Public Function Match(ByVal Test As ITest) As Boolean
    Dim Filter As ITestFilter
    
    For Each Filter In mFilters
        If Filter.Match(Test) = False Then
            Exit Function
        End If
    Next
    
    Match = True
End Function

Public Function Pass(ByVal Test As ITest) As Boolean
    Pass = mBase.Pass(Me, Test)
End Function


'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
'   ITestFilter Interface
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Private Function ITestFilter_Match(ByVal Test As ITest) As Boolean
    ITestFilter_Match = Match(Test)
End Function

Private Function ITestFilter_Pass(ByVal Test As ITest) As Boolean
    ITestFilter_Pass = Pass(Test)
End Function