//
// Copyright (c) 2007, Brian Frank and Andy Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   21 Dec 07  John Sublett   Creation
//

**
** Statement is an executable statement for a specific database.
** A statement may be executed immediately or prepared and
** executed later with parameters.
** See [pod-doc]`pod-doc#statements`.
**
class Statement
{
  **
  ** Make a new statement with the specified SQL text.
  **
  internal new make(SqlConnImpl conn, Str sql)
  {
    this.conn = conn
    this.sql = sql
    init
  }

  private native Void init()

  **
  ** Prepare this statement by compiling for efficient
  ** execution.  Return this.
  **
  native This prepare()

  **
  ** Execute the statement and return the resulting 'List'
  ** of 'Rows'.  The 'Cols' are available from 'List.of.fields' or
  ** on 'type.fields' of each row instance.
  **
  native Row[] query([Str:Obj]? params := null)

  **
  ** Execute the statement.  For each row in the result, invoke
  ** the specified function 'eachFunc'.
  **
  native Void queryEach([Str:Obj]? params, |Row row| eachFunc)

  **
  ** Execute the statement.  For each row in the result, invoke the specified
  ** function 'eachFunc'. If the function returns non-null, then break the
  ** iteration and return the resulting object.  Return null if the function
  ** returns null for every item.
  **
  native Obj? queryEachWhile([Str:Obj]? params, |Row row->Obj?| eachFunc)

  **
  ** Execute a SQL statement and if applicable return a result:
  **   - If the statement is a query or procedure which produces
  **     a result set, then return 'Row[]'
  **   - If the statement is an insert and auto-generated keys
  **     are supported by the connector then return 'Int[]' or 'Str[]'
  **     of keys generated
  **   - Return an 'Int' with the update count
  **
  native Obj execute([Str:Obj]? params := null)

  **
  ** Execute a batch of commands on a prepared Statement. If all commands
  ** execute successfully, returns an array of update counts.
  **
  ** For each element in the array, if the element is non-null, then it
  ** represents an update count giving the number of rows in the database that
  ** were affected by the command's execution.
  **
  ** If a given array element is null, it indicates that the command was
  ** processed successfully but that the number of rows affected is unknown.
  **
  ** If one of the commands in a batch update fails to execute properly, this
  ** method throws a SqlErr that wraps a java.sql.BatchUpdateException, and a
  ** JDBC driver may or may not continue to process the remaining commands in
  ** the batch, consistent with the underlying DBMS -- either always continuing
  ** to process commands or never continuing to process commands.
  **
  native Int?[] executeBatch([Str:Obj]?[] paramsList)

  **
  ** If the last execute has more results from a multi-result stored
  ** procedure, then return the next batch of results as Row[].  Otherwise
  ** if there are no more results then return null.
  **
  @NoDoc native Row[]? more()

  **
  ** Close the statement.
  **
  native Void close()

///////////////////////////////////////////////////////////
// Fields
///////////////////////////////////////////////////////////

  **
  ** The connection that this statement uses.
  **
  internal SqlConnImpl conn { private set }

  **
  ** The SQL text used to create this statement.
  **
  const Str sql

  **
  ** Maximum number of rows returned when this statement is
  ** executed.  If limit is exceeded rows are silently dropped.
  ** A value of null indicates no limit.
  **
  native Int? limit

}

