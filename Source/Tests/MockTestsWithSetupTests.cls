VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
  Persistable = 0  'NotPersistable
  DataBindingBehavior = 0  'vbNone
  DataSourceBehavior  = 0  'vbNone
  MTSTransactionMode  = 0  'NotAnMTSObject
END
Attribute VB_Name = "BootstrapMockTestsWithSetupTests"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = False
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
' Module: BootstrapMockTestsWithSetupTests
'
Option Explicit
Implements IBootstrapTestClass

Private mCount As Long

Public Function Run() As Long
    mCount = 0
    
    RunTest Setup_WhenCalled_AddsToTrace
    RunTest Test1_WhenCalled_AddsToTrace
    RunTest Test2_WhenCalled_AddsToTrace
    
    Run = mCount
End Function

Private Sub RunTest(ByRef v As Variant)
    mCount = mCount + 1
End Sub

Private Function Setup_WhenCalled_AddsToTrace()
    Dim Mock As New Mock2TestsWithSetup
    
    Mock.Setup
    
    Dim Expected As New CallTrace
    Expected.Add "Setup"
    Debug.Assert Mock.Calls.Equals(Expected)
End Function

Private Function Test1_WhenCalled_AddsToTrace()
    Dim Mock As New Mock2TestsWithSetup
    
    Mock.Test1
    
    Dim Expected As New CallTrace
    Expected.Add "Test1"
    Debug.Assert Mock.Calls.Equals(Expected)
End Function

Private Function Test2_WhenCalled_AddsToTrace()
    Dim Mock As New Mock2TestsWithSetup
    
    Mock.Test2
    
    Dim Expected As New CallTrace
    Expected.Add "Test2"
    Debug.Assert Mock.Calls.Equals(Expected)
End Function



Private Function IBootstrapTestClass_Run() As Long
    IBootstrapTestClass_Run = Run
End Function
