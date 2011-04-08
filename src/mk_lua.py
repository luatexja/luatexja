#!python
print 'ltj.ucs2aj16_chars = {'
for line in open ('UniJIS-UTF32-H','r'):
    bucs = -1
    eucs = -1
    code = -1
    if line[:1]=='<':
        bucs = int(line[1:9],16)
        if line[11:12]=='<':
            eucs = int(line[12:20],16)
            code = int(line[21:])
        else:
            code = int(line[11:])
    if eucs==-1:
        eucs = bucs
    if bucs!=-1:
        for i in range(bucs,eucs+1):
            print '[0x%(ucs)06x] = {index=%(cid)d},' % \
                { 'ucs': i, 'cid': i+code-bucs }
print '}'

