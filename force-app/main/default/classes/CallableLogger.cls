//------------------------------------------------------------------------------------------------//
// This file is part of the Nebula Logger project, released under the MIT License.                //
// See LICENSE file or go to https://github.com/jongpie/NebulaLogger for full license details.    //
//------------------------------------------------------------------------------------------------//

/**
 * @group Logger Engine
 * @description A class that implements the standard interface `System.Callable`. This provides 2 benefits:
 *                1. A loosely-coupled way to optionally integrate with Nebula Logger (useful for ISVs/package developers).
 *                2. The ability to log in OmniStudio's OmniScripts & Integration Procedures.
 * @see Logger
 * @see LogEntryEventBuilder
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global without sharing class CallableLogger implements System.Callable {
  // Names of arguments used for both input & output (depending on which action is called)
  private static final String ARGUMENT_EXCEPTION = 'exception';
  private static final String ARGUMENT_LOG_ENTRY_EVENT_BUILDER = 'logEntryEventBuilder';
  private static final String ARGUMENT_LOGGING_LEVEL = 'loggingLevel';
  private static final String ARGUMENT_MESSAGE = 'message';
  private static final String ARGUMENT_PARENT_LOG_TRANSACTION_ID = 'parentLogTransactionId';
  private static final String ARGUMENT_SCENARIO = 'scenario';
  private static final String ARGUMENT_RECORD_ID = 'recordId';
  private static final String ARGUMENT_RECORD = 'record';
  private static final String ARGUMENT_RECORD_LIST = 'recordList';
  private static final String ARGUMENT_RECORD_MAP = 'recordMap';
  private static final String ARGUMENT_SAVE_LOG = 'saveLog';
  private static final String ARGUMENT_SAVE_METHOD_NAME = 'saveMethodName';
  private static final String ARGUMENT_TAGS = 'tags';
  private static final String ARGUMENT_TRANSACTION_ID = 'transactionId';
  // Names of arguments used by OmniStudio when calling an instance of System.Callable
  // Relevant OmniStudio docs: https://help.salesforce.com/s/articleView?id=sf.os_callable_implementations.htm&type=5
  private static final String OMNISTUDIO_ARGUMENT_INPUT = 'input';
  private static final String OMNISTUDIO_ARGUMENT_INPUT_OMNI_PROCESS_ID = 'omniProcessId';
  private static final String OMNISTUDIO_ARGUMENT_OUTPUT = 'output';
  // Names of arguments only used for output
  private static final String OUTPUT_ARGUMENT_CALL_EXCEPTION_MESSAGE = 'exceptionMessage';
  private static final String OUTPUT_ARGUMENT_CALL_EXCEPTION_STACK_TRACE = 'exceptionStackTrace';
  private static final String OUTPUT_ARGUMENT_CALL_EXCEPTION_TYPE = 'exceptionType';
  private static final String OUTPUT_ARGUMENT_CALL_IS_SUCCESS = 'isSuccess';

  @TestVisible
  private static Boolean returnLogEntryEventBuilderInOutput = false;

  /**
   * @description The one method required by the interface `System.Callable` description. It provides a `String`-based way to dynamically call Nebula Logger's code.
   * @param  action    The `String` name of the `Logger` method to call. The supported actions are
   * @param  arguments An instance of `Map<String, Object>` containing any named arguments expected by the `Logger` method being called
   * @return           The value returned by the `Logger` method called as an `Object` instance, or `null` if the method being called does not have a return value
   */
  global Object call(String action, Map<String, Object> arguments) {
    LoggerStackTrace.ignoreOrigin(CallableLogger.class);

    arguments = arguments ?? new Map<String, Object>();
    Map<String, Object> input = (Map<String, Object>) arguments.get(OMNISTUDIO_ARGUMENT_INPUT) ?? arguments;
    Map<String, Object> output = (Map<String, Object>) arguments.get(OMNISTUDIO_ARGUMENT_OUTPUT) ?? new Map<String, Object>();

    try {
      output.put(OUTPUT_ARGUMENT_CALL_IS_SUCCESS, true);
      new CallableHandler().handleCall(action, input, output);
    } catch (System.Exception thrownException) {
      output.put(OUTPUT_ARGUMENT_CALL_IS_SUCCESS, false);
      output.put(OUTPUT_ARGUMENT_CALL_EXCEPTION_MESSAGE, thrownException.getMessage());
      output.put(OUTPUT_ARGUMENT_CALL_EXCEPTION_STACK_TRACE, thrownException.getStackTraceString());
      output.put(OUTPUT_ARGUMENT_CALL_EXCEPTION_TYPE, thrownException.getTypeName());
    }

    return output;
  }

  @SuppressWarnings('PMD.ApexDoc')
  private class CallableHandler {
    public void handleCall(String action, Map<String, Object> input, Map<String, Object> output) {
      switch on action {
        // Methods for transaction IDs / parent transaction IDs
        when 'getTransactionId' {
          output.put(ARGUMENT_TRANSACTION_ID, Logger.getTransactionId());
        }
        when 'getParentLogTransactionId' {
          output.put(ARGUMENT_PARENT_LOG_TRANSACTION_ID, Logger.getParentLogTransactionId());
        }
        when 'setParentLogTransactionId' {
          Logger.setParentLogTransactionId((String) input.get(ARGUMENT_PARENT_LOG_TRANSACTION_ID));
        }
        // Methods for scenario-based logging
        when 'getScenario' {
          output.put(ARGUMENT_SCENARIO, Logger.getScenario());
        }
        when 'setScenario' {
          Logger.setScenario((String) input.get(ARGUMENT_SCENARIO));
        }
        when 'endScenario' {
          Logger.endScenario((String) input.get(ARGUMENT_SCENARIO));
        }
        // Methods for adding & saving log entries
        when 'newEntry' {
          LogEntryEventBuilder builder = this.newEntry(input);
          if (returnLogEntryEventBuilderInOutput) {
            output.put(ARGUMENT_LOG_ENTRY_EVENT_BUILDER, builder);
          }
          if (input.get(ARGUMENT_SAVE_LOG) == true) {
            this.saveLog(input);
          }
        }
        when 'saveLog' {
          this.saveLog(input);
        }
        when else {
          throw new System.IllegalArgumentException('Unknown action: ' + action);
        }
      }
    }

    @SuppressWarnings('PMD.CognitiveComplexity, PMD.NcssMethodCount')
    private LogEntryEventBuilder newEntry(Map<String, Object> input) {
      // The value of loggingLevel could be either a string name or an enum value from System.LoggingLevel,
      // so always first convert it to a string for consistency
      String loggingLevelName = input.get(ARGUMENT_LOGGING_LEVEL)?.toString();
      System.LoggingLevel loggingLevel = Logger.getLoggingLevel(loggingLevelName);
      String message = (String) input.get(ARGUMENT_MESSAGE);

      LogEntryEventBuilder logEntryEventBuilder = Logger.newEntry(loggingLevel, message);

      if (input.containsKey(ARGUMENT_EXCEPTION)) {
        logEntryEventBuilder.setExceptionDetails((System.Exception) input.get(ARGUMENT_EXCEPTION));
      }
      if (input.containsKey(ARGUMENT_RECORD_ID)) {
        logEntryEventBuilder.setRecord((String) input.get(ARGUMENT_RECORD_ID));
      }
      if (input.containsKey(ARGUMENT_RECORD)) {
        logEntryEventBuilder.setRecord((SObject) input.get(ARGUMENT_RECORD));
      }
      if (input.containsKey(ARGUMENT_RECORD_LIST)) {
        logEntryEventBuilder.setRecord((List<SObject>) input.get(ARGUMENT_RECORD_LIST));
      }
      if (input.containsKey(ARGUMENT_RECORD_MAP)) {
        logEntryEventBuilder.setRecord((Map<Id, SObject>) input.get(ARGUMENT_RECORD_MAP));
      }
      if (input.containsKey(ARGUMENT_TAGS)) {
        logEntryEventBuilder.addTags((List<String>) input.get(ARGUMENT_TAGS));
      }
      if (input.containsKey(OMNISTUDIO_ARGUMENT_INPUT_OMNI_PROCESS_ID) || Logger.getCurrentQuiddity() == System.Quiddity.REMOTE_ACTION) {
        LogEntryEvent__e logEntryEvent = logEntryEventBuilder.getLogEntryEvent();
        logEntryEvent.OriginLocation__c = null;
        logEntryEvent.OriginSourceApiName__c = null;
        logEntryEvent.OriginSourceId__c = (String) input.get(OMNISTUDIO_ARGUMENT_INPUT_OMNI_PROCESS_ID);
        logEntryEvent.OriginSourceMetadataType__c = null;
        logEntryEvent.OriginType__c = 'OmniStudio';
      }

      return logEntryEventBuilder;
    }

    private void saveLog(Map<String, Object> input) {
      // The value of saveMethodName could be either a string name or an enum value from Logger.SaveMethod,
      // so always first convert it to a string for consistency
      // System.Assert.fail(input.toString());
      String saveMethodName = input.get(ARGUMENT_SAVE_METHOD_NAME)?.toString() ?? Logger.getUserSettings().DefaultSaveMethod__c;
      Logger.saveLog(saveMethodName);
    }
  }
}