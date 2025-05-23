//------------------------------------------------------------------------------------------------//
// This file is part of the Nebula Logger project, released under the MIT License.                //
// See LICENSE file or go to https://github.com/jongpie/NebulaLogger for full license details.    //
//------------------------------------------------------------------------------------------------//

@SuppressWarnings('PMD.MethodNamingConventions, PMD.PropertyNamingConventions')
@IsTest(IsParallel=true)
private class LoggerFieldMapper_Tests {
  static {
    // Don't use the org's actual custom metadata records when running tests
    LoggerFieldMapper.SOURCE_SOBJECT_TYPE_TO_TARGET_FIELD_MAPPINGS.clear();
  }

  @IsTest
  static void it_safely_returns_when_no_field_mappings_are_configured() {
    LogEntryEvent__e logEntryEvent = new LogEntryEvent__e(Message__c = 'Some value');
    LogEntry__c logEntry = new LogEntry__c();

    LoggerFieldMapper.mapFieldValues(logEntryEvent, logEntry);

    System.Assert.isTrue(logEntry.getPopulatedFieldsAsMap().isEmpty(), System.JSON.serialize(logEntry));
  }

  @IsTest
  static void it_maps_field_value_when_configured() {
    LoggerFieldMapper.setMock(
      new LoggerFieldMapping__mdt(
        DeveloperName = 'SomeDevName',
        IsEnabled__c = true,
        SourceSObjectType__c = Schema.LogEntryEvent__e.SObjectType.getDescribe().getName(),
        SourceField__c = Schema.LogEntryEvent__e.Message__c.getDescribe().getName(),
        TargetSObjectType__c = Schema.LogEntry__c.SObjectType.getDescribe().getName(),
        TargetField__c = Schema.LogEntry__c.Message__c.getDescribe().getName()
      )
    );
    LogEntryEvent__e logEntryEvent = new LogEntryEvent__e(Message__c = 'Some value');
    LogEntry__c logEntry = new LogEntry__c();

    LoggerFieldMapper.mapFieldValues(logEntryEvent, logEntry);

    System.Assert.isTrue(
      logEntry.getPopulatedFieldsAsMap().containsKey(Schema.LogEntry__c.Message__c.getDescribe().getName()),
      System.JSON.serialize(logEntry)
    );
    System.Assert.areEqual(logEntryEvent.Message__c, logEntry.Message__c);
  }

  @IsTest
  static void it_truncates_string_value_when_mapping_string_field_value() {
    LoggerFieldMapper.setMock(
      new LoggerFieldMapping__mdt(
        DeveloperName = 'SomeDevName',
        IsEnabled__c = true,
        SourceSObjectType__c = Schema.LogEntryEvent__e.SObjectType.getDescribe().getName(),
        SourceField__c = Schema.LogEntryEvent__e.Message__c.getDescribe().getName(),
        TargetSObjectType__c = Schema.LogEntry__c.SObjectType.getDescribe().getName(),
        TargetField__c = Schema.LogEntry__c.Message__c.getDescribe().getName()
      )
    );
    Integer messageMaxLength = Schema.LogEntryEvent__e.Message__c.getDescribe().getLength();
    LogEntryEvent__e logEntryEvent = new LogEntryEvent__e(Message__c = 'A'.repeat(messageMaxLength + 1));
    LogEntry__c logEntry = new LogEntry__c();

    LoggerFieldMapper.mapFieldValues(logEntryEvent, logEntry);

    System.Assert.isTrue(
      logEntry.getPopulatedFieldsAsMap().containsKey(Schema.LogEntry__c.Message__c.getDescribe().getName()),
      System.JSON.serialize(logEntry)
    );
    System.Assert.areEqual(
      logEntryEvent.Message__c.left(messageMaxLength),
      logEntry.Message__c,
      'Expected length of ' + logEntryEvent.Message__c.left(messageMaxLength).length() + ', received length ' + logEntry.Message__c.length()
    );
  }

  @IsTest
  static void it_handles_when_field_mappings_are_not_configured_for_current_target_sobject_type_but_do_exist_for_other_types() {
    LoggerFieldMapper.setMock(
      new LoggerFieldMapping__mdt(
        DeveloperName = 'SomeDevName',
        IsEnabled__c = true,
        SourceSObjectType__c = Schema.LogEntryEvent__e.SObjectType.getDescribe().getName(),
        SourceField__c = Schema.LogEntryEvent__e.TransactionId__c.getDescribe().getName(),
        TargetSObjectType__c = Schema.Log__c.SObjectType.getDescribe().getName(),
        TargetField__c = Schema.Log__c.TransactionId__c.getDescribe().getName()
      )
    );
    LogEntryEvent__e logEntryEvent = new LogEntryEvent__e(Message__c = 'Some value');
    LogEntry__c logEntry = new LogEntry__c();

    LoggerFieldMapper.mapFieldValues(logEntryEvent, logEntry);

    System.Assert.isTrue(logEntry.getPopulatedFieldsAsMap().isEmpty(), System.JSON.serialize(logEntry));
  }

  @IsTest
  static void it_safely_skips_field_mappings_for_incompatible_field_mappings() {
    LoggerFieldMapper.setMock(
      new LoggerFieldMapping__mdt(
        DeveloperName = '🥳 Some Valid Mapping',
        IsEnabled__c = true,
        SourceSObjectType__c = Schema.LogEntryEvent__e.SObjectType.getDescribe().getName(),
        SourceField__c = Schema.LogEntryEvent__e.EntryScenario__c.getDescribe().getName(),
        TargetSObjectType__c = Schema.LogEntry__c.SObjectType.getDescribe().getName(),
        TargetField__c = Schema.LogEntry__c.EntryScenario__c.getDescribe().getName()
      )
    );
    LoggerFieldMapper.setMock(
      new LoggerFieldMapping__mdt(
        DeveloperName = '😭 An Incompatible Mapping (mapping a String to a Datetime)',
        IsEnabled__c = true,
        SourceSObjectType__c = Schema.LogEntryEvent__e.SObjectType.getDescribe().getName(),
        SourceField__c = Schema.LogEntryEvent__e.Message__c.getDescribe().getName(),
        TargetSObjectType__c = Schema.LogEntry__c.SObjectType.getDescribe().getName(),
        TargetField__c = Schema.LogEntry__c.Timestamp__c.getDescribe().getName()
      )
    );
    LoggerFieldMapper.setMock(
      new LoggerFieldMapping__mdt(
        DeveloperName = '😀 Another Valid Mapping',
        IsEnabled__c = true,
        SourceSObjectType__c = Schema.LogEntryEvent__e.SObjectType.getDescribe().getName(),
        SourceField__c = Schema.LogEntryEvent__e.TransactionEntryNumber__c.getDescribe().getName(),
        TargetSObjectType__c = Schema.LogEntry__c.SObjectType.getDescribe().getName(),
        TargetField__c = Schema.LogEntry__c.TransactionEntryNumber__c.getDescribe().getName()
      )
    );
    LogEntryEvent__e logEntryEvent = new LogEntryEvent__e(
      EntryScenario__c = 'Some entry scenario',
      Message__c = 'Some value',
      TransactionEntryNumber__c = 9999
    );
    LogEntry__c logEntry = new LogEntry__c(Message__c = 'Some string value that definitely will fail to map to LogEntry__c.Timestamp__c');

    LoggerFieldMapper.mapFieldValues(logEntryEvent, logEntry);

    System.Assert.areEqual(logEntryEvent.EntryScenario__c, logEntry.EntryScenario__c, System.JSON.serialize(logEntry));
    System.Assert.isNull(logEntry.Timestamp__c, System.JSON.serialize(logEntry));
    System.Assert.areEqual(logEntryEvent.TransactionEntryNumber__c, logEntry.TransactionEntryNumber__c, System.JSON.serialize(logEntry));
  }
}