VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
  Persistable = 0  'NotPersistable
  DataBindingBehavior = 0  'vbNone
  DataSourceBehavior  = 0  'vbNone
  MTSTransactionMode  = 0  'NotAnMTSObject
END
Attribute VB_Name = "TestSuite"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = True
'The MIT License (MIT)
'Copyright (c) 2012 Kelly Ethridge
'
'Permission is hereby granted, free of charge, to any person obtaining a copy
'of this software and associated documentation files (the "Software"), to deal
'in the Software without restriction, including without limitation the rights to
'use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
'the Software, and to permit persons to whom the Software is furnished to do so,
'subject to the following conditions:
'
'The above copyright notice and this permission notice shall be included in all
'copies or substantial portions of the Software.
'
'THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
'INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
'PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE
'FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
'OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
'DEALINGS IN THE SOFTWARE.
'
'
' Module: TestSuite
'
Option Explicit
Implements ITest
Implements TestFixture

Private Const DEF_NAME As String = "TestSuite"


Private mTestClass          As Object
Private mParent             As Long
Private mTests              As New TestList
Private mFixtureSetup       As ITestMethod
Private mFixtureTeardown    As ITestMethod
Private mTicks              As Currency
Private mRunState           As RunState
Private mTestCaseContext    As ContextMethods
Private mName               As String
Private mDisplayName        As String
Private mRunner             As ITestRunner
Private mCategories         As Categorization


Public Property Get Categories() As Categorization
    Set Categories = mCategories
End Property

Public Property Set Categories(ByVal RHS As Categorization)
    Set mCategories = RHS
End Property

Public Property Get HasCategories() As Boolean
    If Not mCategories Is Nothing Then
        HasCategories = mCategories.Count > 0
    End If
End Property

Public Property Get This() As TestSuite
Attribute This.VB_MemberFlags = "40"
    Set This = Me
End Property

Public Function CountTestCases(ByVal Filter As ITestFilter) As Long
    Dim Result  As Long
    
    If Filter.Pass(Me) Then
        Dim Test    As ITest
        
        For Each Test In mTests
            Result = Result + Test.CountTestCases(Filter)
        Next
    End If
    
    CountTestCases = Result
End Function

Public Property Get RunState() As RunState
    RunState = mRunState
End Property

Public Property Let RunState(ByVal RHS As RunState)
    mRunState = RHS
End Property

Public Sub Sort(Optional ByVal Comparer As ITestComparer)
    mTests.Sort Comparer
    
    Dim Test As ITest
    For Each Test In mTests
        Test.Sort Comparer
    Next
End Sub

Public Property Get Parent() As ITest
    Set Parent = TestUtils.ObjectFromPointer(mParent)
End Property

Public Property Set Parent(ByVal RHS As ITest)
    mParent = ObjPtr(RHS)
End Property

Public Property Get HasParent() As Boolean
    HasParent = (mParent <> vbNullPtr)
End Property

Public Function Add(ByVal TestClass As Object, Optional ByRef Name As String) As TestSuite
    If TestClass Is Nothing Then _
        Error.CannotBeNothing Me, "Add", "TestClass"
    
    Dim Test As ITest
    If TypeOf TestClass Is ITest Then
        Set Test = TestClass
    Else
        Set Test = Sim.NewTestFixture(TestClass, Name)
    End If
    
    Set Test.Parent = Me
    mTests.Add Test
    
    Set Add = Me
End Function

Public Property Get TestCount() As Long
    Dim Test    As ITest
    Dim Result  As Long

    For Each Test In mTests
        Result = Result + Test.TestCount
    Next

    TestCount = Result
End Property

Public Property Get Tests() As TestList
    Set Tests = mTests
End Property

Public Function Run(Optional ByVal Listener As IEventListener, Optional ByVal Filter As ITestFilter) As TestResult
    If Listener Is Nothing Then
        Set Listener = NullListener.Instance
    End If
    If Filter Is Nothing Then
        Set Filter = TestFilter.EmptyFilter
    End If
    
    Dim Result As TestResult
    Set Result = Sim.NewTestResult(Me)
    
    With New TestContext
        Listener.TestSuiteStarted Me
        
        If Me.RunState = RunnableRunState Then
            Result.Success
            InitMetrics
            
            If RunFixtureSetup(Result) = True Then
                RunTests Result, Listener, Filter
            End If
            
            RunFixtureTeardown
            RecordMetrics Result
            
            If Result.Results.Count = 0 Then
                Result.SetResult InconclusiveState
            End If
        Else
            Result.Invalid
        End If
        
        Listener.TestSuiteFinished Result
    End With
    
    Set Run = Result
End Function

Public Property Get Name() As String
    Name = mName
End Property

Public Property Get DisplayName() As String
    DisplayName = mName & " (" & TestCount & " Tests)"
End Property

Public Property Get FullName() As String
    FullName = TestUtils.BuildFullName(Me)
End Property

Public Property Get IsSuite() As Boolean
    IsSuite = True
End Property

Public Property Get TestClass() As Object
    Set TestClass = mTestClass
End Property


'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
'   Friend Methods
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Friend Sub InitTestSuite(ByRef Name As String)
    mName = Name
End Sub

Friend Sub InitTestFixture(ByVal TestClass As Object, ByRef Name As String)
    If TestClass Is Nothing Then _
        Error.CannotBeNothing New TestFixture, "Init", "TestClass"
    
    Set mTestClass = TestClass
    InitTestSuite IIf(Len(Name) > 0, Name, TypeName(TestClass))
    
    If TypeOf TestClass Is ITestFixture Then
        ManuallyBuildFixture
    Else
        AutomaticallyBuildFixture
    End If
    CategorizeTestClass
End Sub


'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
'   Private Helpers
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Private Sub RunTests(ByVal Result As TestResult, ByVal Listener As IEventListener, ByVal Filter As ITestFilter)
    Dim Test As ITest
    
    For Each Test In mTests
        If Filter.Pass(Test) Then
            Test.RunState = Me.RunState
            Result.AddResult Test.Run(Listener, Filter)
        End If
    Next
End Sub

Private Sub InitMetrics()
    StartTiming
End Sub

Private Sub StartTiming()
    mTicks = Timing.GetTicks
End Sub

Private Sub RecordMetrics(ByVal Result As TestResult)
    Result.Time = StopTiming
    Result.AssertCount = TestContext.AssertCount
End Sub

Private Function StopTiming() As Currency
    StopTiming = Timing.GetTime(mTicks)
End Function

Private Sub ManuallyBuildFixture()
    CreateTestCaseContext "Setup", "Teardown"
    CreateTestFixtureContext "FixtureSetup", "FixtureTeardown"
    
    Dim Fixture As ITestFixture
    Set Fixture = mTestClass
    Dim Builder As New TestFixtureBuilder
    Fixture.GetTestCases Builder
    
    Dim Count       As Long
    Dim Collector   As TestCaseCollector
    Dim Method      As ITestMethod
    Dim Test        As TestCase
    For Each Collector In Builder
        If Collector.DataStore.Count > 0 Then
            Dim Scenario As TestCaseData
            For Each Scenario In Collector.DataStore
                If Scenario.HasArguments Then
                    Set Method = Sim.NewParameterizedTestMethod(mTestClass, Collector.MethodName, Scenario)
                Else
                    Set Method = Sim.NewSimpleTestMethod(mTestClass, Collector.MethodName)
                End If
                
                Dim Name As String
                Count = Count + 1
                Name = Collector.MethodName & "_" & Count
                
                Set Test = Sim.NewTestCase(Name, Name, Method)
                AddTestCase Test
            Next
        Else
            Set Method = Sim.NewSimpleTestMethod(mTestClass, Collector.MethodName)
            Set Test = Sim.NewTestCase(Collector.MethodName, Collector.MethodName, Method)
            AddTestCase Test
        End If
    Next
    
    SetContext mTests
End Sub

Private Sub AutomaticallyBuildFixture()
    Dim Result As QueryResult
    Set Result = QueryTestClass
    
    CreateContextMethods Result
    BuildTestCasesFromMembers Result.TestCaseMembers
    SetContext mTests
End Sub

Private Function QueryTestClass() As QueryResult
    Dim Query As New MemberQuery
    Set QueryTestClass = Query.Execute(mTestClass)
End Function

Private Sub CreateContextMethods(ByVal Result As QueryResult)
    CreateTestCaseContext Result.SetupMember, Result.TeardownMember
    CreateTestFixtureContext Result.FixtureSetupMember, Result.FixtureTeardownMember
End Sub

Private Sub CreateTestCaseContext(ByRef SetupMember As Variant, ByRef TeardownMember As Variant)
    Dim SetupMethod     As ITestMethod
    Dim TeardownMethod  As ITestMethod
    
    Set SetupMethod = BuildContextMethod(SetupMember)
    Set TeardownMethod = BuildContextMethod(TeardownMember)
    Set mTestCaseContext = Sim.NewContextMethods(SetupMethod, TeardownMethod)
End Sub

Private Sub CreateTestFixtureContext(ByRef FixtureSetupMember As Variant, ByRef FixtureTeardownMember As Variant)
    Set mFixtureSetup = BuildContextMethod(FixtureSetupMember)
    Set mFixtureTeardown = BuildContextMethod(FixtureTeardownMember)
End Sub

Private Function BuildContextMethod(ByRef MemberId As Variant) As ITestMethod
    If ContextMemberWasFound(MemberId) Then
        Set BuildContextMethod = Sim.NewSimpleTestMethod(mTestClass, MemberId)
    Else
        Set BuildContextMethod = NullMethod.Instance
    End If
End Function

Private Function ContextMemberWasFound(ByRef MemberId As Variant) As Boolean
    ContextMemberWasFound = Not IsEmpty(MemberId)
End Function

Private Sub BuildTestCasesFromMembers(ByVal Members As Collection)
    Dim Member As MemberInfo
    
    For Each Member In Members
        BuildTestCases Member
    Next
End Sub

Private Sub BuildTestCases(ByVal Member As MemberInfo)
    Dim Test As ITest
    
    For Each Test In TestCaseBuilder.BuildFrom(mTestClass, Member)
        AddTestCase Test
    Next
End Sub

Private Sub CategorizeTestClass()
    If TypeOf mTestClass Is ICategorizable Then
        Dim Store As CategoryStore
        Set Store = Sim.NewCategoryStore(Me.Name)
        Dim Collector As CategoryCollector
        Set Collector = Sim.NewCategoryCollector(Store)
        
        Dim Categorizable As ICategorizable
        Set Categorizable = mTestClass
        Categorizable.Categorize Collector
        
        If Store.FixtureCategorization.Count > 0 Then
            Set mCategories = Store.FixtureCategorization
        End If
        
        Dim Test As ITest
        For Each Test In mTests
            Set Test.Categories = Store.GetTestCategorization(Test.Name)
        Next
    End If
End Sub

Private Sub AddTestCase(ByVal Test As ITest)
    Set Test.Parent = Me
    mTests.Add Test
End Sub

Private Sub SetContext(ByVal Tests As TestList)
    Dim Test As ITest
    For Each Test In Tests
        If Test.IsSuite Then
            SetContext Test.Tests
        Else
            AssignContextToTestCase Test
        End If
    Next
End Sub

Private Sub AssignContextToTestCase(ByVal Test As TestCase)
    Set Test.Context = mTestCaseContext
End Sub

Private Function RunFixtureSetup(ByVal FixtureResult As TestResult) As Boolean
    On Error GoTo errTrap
    
    mFixtureSetup.Run
    
    RunFixtureSetup = True
    Exit Function
    
errTrap:
    Const ERR_METHODNOTFOUND As Long = 438
    If Err.Number = ERR_METHODNOTFOUND Then
        RunFixtureSetup = True
        Exit Function
    End If
    
    FixtureResult.Error Resource.GetString(Msg_FixtureSetupFailed), SetupSite
    FailAllTests mTests, FixtureResult
End Function

Private Sub FailAllTests(ByVal Tests As TestList, ByVal ParentResult As TestResult)
    Dim Test As ITest
    For Each Test In Tests
        Dim Result As TestResult
        Set Result = Sim.NewTestResult(Test)
        Result.Failure Resource.GetString(Msg_FixtureSetupFailed), ParentSite
        ParentResult.AddResult Result
        
        If Test.IsSuite Then
            FailAllTests Test.Tests, Result
        End If
    Next
End Sub

Private Sub RunFixtureTeardown()
    On Error GoTo errTrap
    
    mFixtureTeardown.Run
errTrap:
End Sub


'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
'   Class Events
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Private Sub Class_Initialize()
    InitTestSuite DEF_NAME
    Set mFixtureSetup = NullMethod.Instance
    Set mFixtureTeardown = NullMethod.Instance
    Set mRunner = NullTestRunner.Instance
End Sub

Private Sub Class_Terminate()
    TestUtils.ClearParents mTests
End Sub


'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
'   ITest Interface
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Private Property Set ITest_Categories(ByVal RHS As Categorization)
    Set Categories = RHS
End Property

Private Property Get ITest_Categories() As Categorization
    Set ITest_Categories = Categories
End Property

Private Function ITest_CountTestCases(ByVal Filter As ITestFilter) As Long
    ITest_CountTestCases = CountTestCases(Filter)
End Function

Private Property Get ITest_DisplayName() As String
    ITest_DisplayName = DisplayName
End Property

Private Property Get ITest_FullName() As String
    ITest_FullName = FullName
End Property

Private Property Get ITest_HasCategories() As Boolean
    ITest_HasCategories = HasCategories
End Property

Private Property Get ITest_HasParent() As Boolean
    ITest_HasParent = HasParent
End Property

Private Property Get ITest_IsSuite() As Boolean
    ITest_IsSuite = IsSuite
End Property

Private Property Get ITest_Parent() As ITest
    Set ITest_Parent = Parent
End Property

Private Property Set ITest_Parent(ByVal RHS As ITest)
    Set Parent = RHS
End Property

Private Property Get ITest_Name() As String
    ITest_Name = Name
End Property

Private Function ITest_Run(Optional ByVal Listener As IEventListener, Optional ByVal Filter As ITestFilter) As TestResult
    Set ITest_Run = Run(Listener, Filter)
End Function

Private Property Let ITest_RunState(ByVal RHS As RunState)
    RunState = RHS
End Property

Private Property Get ITest_RunState() As RunState
    ITest_RunState = RunState
End Property

Private Sub ITest_SetRunner(ByVal Runner As ITestRunner)
    Dim Test As ITest
    For Each Test In mTests
        Test.SetRunner Runner
    Next
End Sub

Private Sub ITest_Sort(Optional ByVal Comparer As ITestComparer)
    Sort Comparer
End Sub

Private Property Get ITest_TestClass() As Object
    Set ITest_TestClass = TestClass
End Property

Private Property Get ITest_TestCount() As Long
    ITest_TestCount = TestCount
End Property

Private Property Get ITest_Tests() As TestList
    Set ITest_Tests = Tests
End Property


'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
'   TestFixture Interface
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Private Property Set TestFixture_Categories(ByVal RHS As Categorization)
    Set Categories = RHS
End Property

Private Property Get TestFixture_Categories() As Categorization
    Set TestFixture_Categories = Categories
End Property

Private Function TestFixture_CountTestCases(ByVal Filter As ITestFilter) As Long
    TestFixture_CountTestCases = CountTestCases(Filter)
End Function

Private Property Get TestFixture_FullName() As String
    TestFixture_FullName = FullName
End Property

Private Property Get TestFixture_HasCategories() As Boolean
    TestFixture_HasCategories = HasCategories
End Property

Private Property Get TestFixture_HasParent() As Boolean
    TestFixture_HasParent = HasParent
End Property

Private Property Get TestFixture_IsSuite() As Boolean
    TestFixture_IsSuite = IsSuite
End Property

Private Property Get TestFixture_Name() As String
    TestFixture_Name = Name
End Property

Private Property Set TestFixture_Parent(ByVal RHS As ITest)
    Set Parent = RHS
End Property

Private Property Get TestFixture_Parent() As ITest
    Set TestFixture_Parent = Parent
End Property

Private Function TestFixture_Run(Optional ByVal Listener As IEventListener, Optional ByVal Filter As ITestFilter) As TestResult
    Set TestFixture_Run = Run(Listener, Filter)
End Function

Private Property Let TestFixture_RunState(ByVal RHS As RunState)
    RunState = RHS
End Property

Private Property Get TestFixture_RunState() As RunState
    TestFixture_RunState = RunState
End Property

Private Sub TestFixture_Sort(Optional ByVal Comparer As ITestComparer)
    Sort Comparer
End Sub

Private Property Get TestFixture_TestClass() As Object
    Set TestFixture_TestClass = TestClass
End Property

Private Property Get TestFixture_TestCount() As Long
    TestFixture_TestCount = TestCount
End Property

Private Property Get TestFixture_Tests() As TestList
    Set TestFixture_Tests = Tests
End Property
