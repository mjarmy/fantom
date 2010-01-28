//
// Copyright (c) 2010, Brian Frank and Andy Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   27 Jan 10  Brian Frank  Creation
//
package fan.sys;

import java.lang.management.*;
import java.util.Iterator;
import fanx.util.*;

/**
 * BootEnv
 */
public class BootEnv
  extends Env
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  public BootEnv()
  {
    this.args    = initArgs();
    this.vars    = initVars();
    this.host    = initHost();
    this.user    = initUser();
    this.in      = new SysInStream(System.in);
    this.out     = new SysOutStream(System.out);
    this.err     = new SysOutStream(System.err);
    this.homeDir = new LocalFile(Sys.homeDir, true).normalize();
    this.tempDir = homeDir.plus(Uri.fromStr("temp/"), false);
  }

  private static List initArgs()
  {
    return (List)new List(Sys.StrType).toImmutable();
  }

  private static Map initVars()
  {
    Map vars = new Map(Sys.StrType, Sys.StrType);
    try
    {
      vars.caseInsensitive(true);

      // environment variables
      java.util.Map getenv = System.getenv();
      Iterator it = getenv.keySet().iterator();
      while (it.hasNext())
      {
        String key = (String)it.next();
        String val = (String)getenv.get(key);
        vars.set(key, val);
      }

      // Java system properties
      it = System.getProperties().keySet().iterator();
      while (it.hasNext())
      {
        String key = (String)it.next();
        String val = System.getProperty(key);
        vars.set(key, val);
      }

      // sys.properties
      LocalFile f = new LocalFile(new java.io.File(Sys.homeDir, "lib" + java.io.File.separator + "sys.props"));
      if (f.exists())
      {
        try
        {
          Map props = f.readProps();
          vars.setAll(props);
        }
        catch (Exception e)
        {
          System.out.println("ERROR: Invalid props file: " + f);
          System.out.println("  " + e);
        }
      }
    }
    catch (Throwable e)
    {
      e.printStackTrace();
    }
    return (Map)vars.toImmutable();
  }

  private static String initHost()
  {
    try
    {
      return java.net.InetAddress.getLocalHost().getHostName();
    }
    catch (Throwable e)
    {
      return "unknown";
    }
  }

  private static String initUser()
  {
    return System.getProperty("user.name", "unknown");
  }

//////////////////////////////////////////////////////////////////////////
// BootEnv
//////////////////////////////////////////////////////////////////////////

  public void setArgs(String[] args)
  {
    this.args = (List)new List(Sys.StrType, args).toImmutable();
  }

//////////////////////////////////////////////////////////////////////////
// Obj
//////////////////////////////////////////////////////////////////////////

  public Type typeof() { return Sys.BootEnvType; }

//////////////////////////////////////////////////////////////////////////
// Virtuals
//////////////////////////////////////////////////////////////////////////

  public List args() { return args; }

  public Map vars()  { return vars; }

  public String host() { return host; }

  public String user() { return user; }

  public void gc() { System.gc(); }

  public void exit(long status) { System.exit((int)status); }

  public InStream in() { return in; }

  public OutStream out() { return out; }

  public OutStream err() { return err; }

  public File homeDir() { return homeDir; }

  // TODO
  public File workDir() { return Repo.working().home(); }

  public File tempDir() { return tempDir; }

  public Type compileScript(fan.sys.File file, Map options)  { return ScriptUtil.compile(file, options); }

//////////////////////////////////////////////////////////////////////////
// Diagnostics
//////////////////////////////////////////////////////////////////////////

  public Map diagnostics()
  {
    Map d = new Map(Sys.StrType, Sys.ObjType);

    // memory
    MemoryMXBean mem = ManagementFactory.getMemoryMXBean();
    d.add("mem.heap",    Long.valueOf(mem.getHeapMemoryUsage().getUsed()));
    d.add("mem.nonHeap", Long.valueOf(mem.getNonHeapMemoryUsage().getUsed()));

    // threads
    ThreadMXBean thread = ManagementFactory.getThreadMXBean();
    long[] threadIds = thread.getAllThreadIds();
    d.add("thread.size", Long.valueOf(threadIds.length));
    for (int i=0; i<threadIds.length; ++i)
    {
      ThreadInfo ti = thread.getThreadInfo(threadIds[i]);
      d.add("thread." + i + ".name",    ti.getThreadName());
      d.add("thread." + i + ".state",   ti.getThreadState().toString());
      d.add("thread." + i + ".cpuTime", Duration.make(thread.getThreadCpuTime(threadIds[i])));
    }

    // class loading
    ClassLoadingMXBean cls = ManagementFactory.getClassLoadingMXBean();
    d.add("classes.loaded",   Long.valueOf(cls.getLoadedClassCount()));
    d.add("classes.total",    Long.valueOf(cls.getTotalLoadedClassCount()));
    d.add("classes.unloaded", Long.valueOf(cls.getUnloadedClassCount()));

    return d;
  }

//////////////////////////////////////////////////////////////////////////
// Find Files
//////////////////////////////////////////////////////////////////////////

  public File findFile(Uri uri, boolean checked)
  {
    if (uri.isPathAbs()) throw ArgErr.make("Uri must be relative: " + uri).val;
    File f = homeDir.plus(uri, false);
    if (f.exists()) return f;
    if (!checked) return null;
    throw IOErr.make("File not found in Env: " + uri).val;
  }

  public List findAllFiles(Uri uri)
  {
    File f = findFile(uri, false);
    if (f == null) return Sys.FileType.emptyList();
    return new List(Sys.FileType, new File[] { f });
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private List args;
  private final Map vars;
  private final String host;
  private final String user;
  private final InStream  in;
  private final OutStream out;
  private final OutStream err;
  private final File homeDir;
  private final File tempDir;

}

