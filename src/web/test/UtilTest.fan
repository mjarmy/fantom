//
// Copyright (c) 2007, Brian Frank and Andy Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   27 Jul 07  Brian Frank  Creation
//

**
** UtilTest
**
@Js
class UtilTest : Test
{

  Void testIsToken()
  {
    verifyEq(WebUtil.isToken(""), false)
    verifyEq(WebUtil.isToken("x"), true)
    verifyEq(WebUtil.isToken("x y"), false)
    verifyEq(WebUtil.isToken("5a-3dd_33*&^%22!~"), true)
    verifyEq(WebUtil.isToken("(foo)"), false)
    verifyEq(WebUtil.isToken("foo;bar"), false)

    // test https://tools.ietf.org/html/rfc7230#section-3.2.6
    chars := Int:Bool[:] { def = false }
    ('0'..'9').each |c| { chars[c] = true }
    ('a'..'z').each |c| { chars[c] = true }
    ('A'..'Z').each |c| { chars[c] = true }
    "!#\$%&'*+-.^_`|~".each |c| { chars[c] = true }
    for (c:=0; c<130; ++c)
      verifyEq(WebUtil.isTokenChar(c), chars[c])
  }

  Void testToQuotedStr()
  {
    verifyQuotedStr("", "\"\"")
    verifyQuotedStr("foo bar", "\"foo bar\"")
    verifyQuotedStr("foo\"bar\"baz", "\"foo\\\"bar\\\"baz\"")

    verifyErr(ArgErr#) { WebUtil.toQuotedStr("foo\nbar") }
    verifyErr(ArgErr#) { WebUtil.toQuotedStr("\u007f") }
    verifyErr(ArgErr#) { WebUtil.toQuotedStr("\u024a") }

    verifyErr(ArgErr#) { WebUtil.fromQuotedStr("") }
    verifyErr(ArgErr#) { WebUtil.fromQuotedStr("\"") }
    verifyErr(ArgErr#) { WebUtil.fromQuotedStr("\"x") }
    verifyErr(ArgErr#) { WebUtil.fromQuotedStr("x\"") }
  }

  Void verifyQuotedStr(Str s, Str expected)
  {
    verifyEq(WebUtil.toQuotedStr(s), expected)
    verifyEq(WebUtil.fromQuotedStr(expected), s)
  }

  Void testParseList()
  {
    verifyEq(WebUtil.parseList("a"), ["a"])
    verifyEq(WebUtil.parseList(" a "), ["a"])
    verifyEq(WebUtil.parseList("a, bob, c,delta "), ["a", "bob", "c", "delta"])
  }

  Void testParseHeaders()
  {
    in :=
      ("Host: foobar\r\n" +
      "Extra1:  space\r\n" +
      "Extra2: space  \r\n" +
      "Cont: one two \r\n" +
      "  three\r\n" +
      "\tfour\r\n" +
      "Coalesce: a,b\r\n" +
      "Coalesce: c\r\n" +
      "Coalesce:  d\r\n" +
      "\r\n").toBuf.in

     headers := WebUtil.parseHeaders(in)
     verifyEq(headers.caseInsensitive, true)
     verifyEq(headers,
       [
        "Host":     "foobar",
        "Extra1":   "space",
        "Extra2":   "space",
        "Cont":     "one two three four",
        "Coalesce": "a,b,c,d",
       ])
  }

  Void testChunkInStream()
  {
    str := "3\r\nxyz\r\nB\r\nhello there\r\n0\r\n\r\n"

    // readAllStr
    in := WebUtil.makeChunkedInStream(str.toBuf.in)
    verifyEq(in.readAllStr, "xyzhello there")

    // readBuf chunks
    in = WebUtil.makeChunkedInStream(str.toBuf.in)
    buf := Buf()
    verifyEq(in.readBuf(buf.clear, 20), 3)
    verifyEq(buf.flip.readAllStr, "xyz")
    verifyEq(in.readBuf(buf.clear, 20), 11)
    verifyEq(buf.flip.readAllStr, "hello there")
    verifyEq(in.readBuf(buf.clear, 20), null)
    verifyEq(in.readBuf(buf.clear, 20), null)

    // readBufFully
    in = WebUtil.makeChunkedInStream(str.toBuf.in)
    in.readBufFully(buf.clear, 14)
    verifyEq(buf.readAllStr, "xyzhello there")
    verifyEq(in.read, null)
    verifyEq(in.readChar, null)
    verifyEq(in.read, null)

    // unread
    in = WebUtil.makeChunkedInStream(str.toBuf.in)
    verifyEq(in.read, 'x')
    verifyEq(in.read, 'y')
    in.unread('?')
    verifyEq(in.read, '?')
    in.unread('2').unread('1')
    in.readBufFully(buf.clear, 14)
    verifyEq(buf.readAllStr, "12zhello there")

    // fixed chunked stream
    in = WebUtil.makeFixedInStream("abcdefgh".toBuf.in, 3)
    verifyEq(in.readAllStr, "abc")
  }

  Void testFixedOutStream()
  {
    buf := Buf()
    out := WebUtil.makeFixedOutStream(buf.out, 4)
    out.print("abcd")
    verifyErr(IOErr#) { out.write('x') }
    verifyEq(buf.flip.readAllStr, "abcd")

    buf2 := Buf()
    buf.seek(0)
    out = WebUtil.makeFixedOutStream(buf2.out, 2)
    out.writeBuf(buf, 2)
    verifyErr(IOErr#) { out.writeBuf(buf, 1) }
    verifyEq(buf2.flip.readAllStr, "ab")
  }

  Void testChunkOutStream()
  {
    buf := Buf()
    out := WebUtil.makeChunkedOutStream(buf.out)
    2000.times |Int i| { out.printLine(i) }
    out.close

    in := WebUtil.makeChunkedInStream(buf.flip.in)
    2000.times |Int i| { verifyEq(in.readLine, i.toStr) }
    verifyEq(in.read, null)
  }

  Void testParseQVals()
  {
    verifyEq(WebUtil.parseQVals(""), Str:Float[:])
    verifyEq(WebUtil.parseQVals("compress"), Str:Float["compress":1.0f])
    verifyEq(WebUtil.parseQVals("compress,gzip"), Str:Float["compress":1.0f, "gzip": 1.0f])
    verifyEq(WebUtil.parseQVals("compress;q=0.7,gzip;q=0.0"), Str:Float["compress":0.7f, "gzip": 0f])

    q := WebUtil.parseQVals("foo , compress ; q=0.8 , gzip ; q=0.5 , bar; q=x")
    verifyEq(q, Str:Float["foo":1.0f, "compress": 0.8f, "gzip": 0.5f, "bar":1.0f])
    verifyEq(q["compress"], 0.8f)
    verifyEq(q["def"], 0.0f)
  }

  Void testParseMultiPart()
  {
    // couple empty posts
    s :=
    """------WebKitFormBoundaryvx0NalAyBZjdpZAe
       Content-Disposition: form-data; name="file1"; filename="empty.txt"


       ------WebKitFormBoundaryvx0NalAyBZjdpZAe
       Content-Disposition: form-data; name="file2"; filename="empty.txt"


       ------WebKitFormBoundaryvx0NalAyBZjdpZAe--
       """

    boundary := "----WebKitFormBoundaryvx0NalAyBZjdpZAe"
    WebUtil.parseMultiPart(s.replace("\n", "\r\n").toBuf.in, boundary) |h, in|
    {
      verify(h["Content-Disposition"].startsWith("form-data"))
      verifyEq(in.readAllStr, "")
    }

    // test real post from IE using test data below
    boundary = "---------------------------7dacb195e0632"
    base64 :=
      "LS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS03ZGFjYjE5NWUwNjMyDQpDb250ZW5
       0LURpc3Bvc2l0aW9uOiBmb3JtLWRhdGE7IG5hbWU9ImZpbGUxIjsgZmlsZW5hbWU9Ik
       M6XGRldlxmYW5cbXVsdGlwYXJ0LWEudHh0Ig0KQ29udGVudC1UeXBlOiB0ZXh0L3BsY
       WluDQoNCmZvbyBiYXINCi0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tN2RhY2Ix
       OTVlMDYzMg0KQ29udGVudC1EaXNwb3NpdGlvbjogZm9ybS1kYXRhOyBuYW1lPSJmaWx
       lMiI7IGZpbGVuYW1lPSJDOlxkZXZcZmFuXG11bHRpcGFydC1iLnR4dCINCkNvbnRlbn
       QtVHlwZTogdGV4dC9wbGFpbg0KDQoAAQIDBAUGBwgJCgsMDQ4PEBESExQVFhcYGRobH
       B0eHyAhIiMkJSYnKCkqKywtLi8wMTIzNDU2Nzg5Ojs8PT4/QEFCQ0RFRkdISUpLTE1O
       T1BRUlNUVVZXWFlaW1xdXl9gYWJjZGVmZ2hpamtsbW5vcHFyc3R1dnd4eXp7fH1+f4C
       BgoOEhYaHiImKi4yNjo+QkZKTlJWWl5iZmpucnZ6foKGio6SlpqeoqaqrrK2ur7Cxsr
       O0tba3uLm6u7y9vr/AwcLDxMXGxw0KLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tL
       S03ZGFjYjE5NWUwNjMyDQpDb250ZW50LURpc3Bvc2l0aW9uOiBmb3JtLWRhdGE7IG5h
       bWU9ImZpbGUzIjsgZmlsZW5hbWU9IkM6XGRldlxmYW5cbXVsdGlwYXJ0LWMudHh0Ig0
       KQ29udGVudC1UeXBlOiB0ZXh0L3BsYWluDQoNCi0tLS0tLS0NCi0tLS0tLS0NCi0tLS
       0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tN2RhY2IxOTVlMDYzMi0tDQo="
    count := 0
    WebUtil.parseMultiPart(Buf.fromBase64(base64).in, boundary) |h, in|
    {
      switch (count++)
      {
        // verify no extra newlines
        case 0:
          verifyEq(in.readAllStr, "foo bar")

        // verify binary data, readBuf, and unread
        case 1:
          100.times |i| { verifyEq(in.readU1, i) }
          in.unread(0xab).unread(0xcd)
          verifyEq(in.readU2, 0xcdab)
          buf := Buf()
          in.readBufFully(buf, 100)
          100.times |i| { verifyEq(buf[i], 100+i) }
          verifyNull(in.read)

        // verify data that might look like boundaries
        case 2:
          verifyEq(in.readAllStr(false), "-------\r\n-------")
      }
    }

    // single item
    boundary = "---------------------------41184676334"
    s =
     """-----------------------------41184676334
        Content-Disposition: form-data; name=""; filename="something.txt"
        Content-Type: text/plain

        hello world
        -----------------------------41184676334--
        """
    buf := Buf()
    numRead := 0
    WebUtil.parseMultiPart(s.replace("\n", "\r\n").toBuf.in, boundary) |h, in|
    {
      in.pipe(buf.out)
      numRead = in->numRead
    }
    verifyEq(buf.flip.readAllStr, "hello world")
    verifyEq(numRead, 11)

    // mixed
    s =
     """------WebKitFormBoundaryZ7PdCaCUA42JfPxv
        Content-Disposition: form-data; name="name"

        FooBar
        ------WebKitFormBoundaryZ7PdCaCUA42JfPxv
        Content-Disposition: form-data; name="ver"

        1.0.5
        ------WebKitFormBoundaryZ7PdCaCUA42JfPxv
        Content-Disposition: form-data; name="file"; filename="temp.txt"
        Content-Type: application/octet-stream

        Hello,
        World
        :)
        ------WebKitFormBoundaryZ7PdCaCUA42JfPxv--
        """
    boundary = "----WebKitFormBoundaryZ7PdCaCUA42JfPxv"
    numRead = 0
    WebUtil.parseMultiPart(s.replace("\n", "\r\n").toBuf.in, boundary) |h, in|
    {
      numRead++
      disp := h["Content-Disposition"]
      verify(disp.startsWith("form-data;"))

      map := MimeType.parseParams(disp["form-data;".size..-1].trim)
      switch (map["name"])
      {
        case "name": verifyEq(in.readAllStr, "FooBar")
        case "ver":  verifyEq(in.readAllStr, "1.0.5")
        case "file": verifyEq(in.readAllStr, "Hello,\nWorld\n:)")
      }
    }
    verifyEq(numRead, 3)
  }

  // generate test files for testParseMultiPart
  static Void main(Str[] args)
  {
    `multipart-a`.toFile.out.print("foo bar").close

    out := `multipart-b`.toFile.out
    200.times |i| { out.write(i) }
    out.close

    `multipart-c`.toFile.out.print("-------\r\n-------").close
  }

  Void testMultiPart1023()
  {
    bound    := "XXXXX"
    buf      := Buf()
    out      := buf.out

    // multi-part form with x2 parts
    out.print("--").print(bound).print("\r\n")
    out.print("name: foo1\r\n")    // Part1 = foo1
    out.print("\r\n")
    1023.times |i| { out.write(i == 1022 ? 0xab : 0) }    // 1023 is the MAGIC bad number!
    out.print("\r\n")

    out.print("--").print(bound).print("\r\n")
    out.print("name: foo2\r\n")    // Part2 = foo2
    out.print("\r\n")
    out.print("Data-Data-Data")
    out.print("\r\n")

    out.print("--").print(bound).print("--\r\n")

    // parse it with WebUtil
    names := Str[,]
    vals  := Buf[,]
    WebUtil.parseMultiPart(buf.flip.in, bound) |headers, InStream in|
    {
      names.add(headers["name"])
      vals.add(in.readAllBuf)   // drain the part stream
    }

    verifyEq(names, ["foo1", "foo2"])
    verifyEq(vals.size, 2)
    verifyEq(vals[0].size, 1023)
    verifyEq(vals[0].get(1022), 0xab)
    verifyEq(vals[1].size, 14)
  }
}

