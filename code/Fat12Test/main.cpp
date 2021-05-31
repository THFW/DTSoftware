#include <QtCore/QCoreApplication>
#include <QFile>
#include <QDataStream>
#include <QDebug>

#pragma pack(push)
#pragma pack(1)

struct Fat12Header
{
    char BS_OEMName[8];
    ushort BPB_BytsPerSec;
    uchar BPB_SecPerClus;
    ushort BPB_RsvdSecCnt;
    uchar BPB_NumFATs;
    ushort BPB_RootEntCnt;
    ushort BPB_TotSec16;
    uchar BPB_Media;
    ushort BPB_FATSz16;
    ushort BPB_SecPerTrk;
    ushort BPB_NumHeads;
    uint BPB_HiddSec;
    uint BPB_TotSec32;
    uchar BS_DrvNum;
    uchar BS_Reserved1;
    uchar BS_BootSig;
    uint BS_VolID;
    char BS_VolLab[11];
    char BS_FileSysType[8];
};

#pragma pack(pop)

void PrintHeader(Fat12Header& rf, QString p)
{
    QFile file(p);

    if( file.open(QIODevice::ReadOnly) )
    {
        QDataStream in(&file);

        file.seek(3);

        in.readRawData(reinterpret_cast<char*>(&rf), sizeof(rf));

        rf.BS_OEMName[7] = 0;
        rf.BS_VolLab[10] = 0;
        rf.BS_FileSysType[7] = 0;

        qDebug() << "BS_OEMName: " << rf.BS_OEMName;
        qDebug() << "BPB_BytsPerSec: " << hex << rf.BPB_BytsPerSec;
        qDebug() << "BPB_SecPerClus: " << hex << rf.BPB_SecPerClus;
        qDebug() << "BPB_RsvdSecCnt: " << hex << rf.BPB_RsvdSecCnt;
        qDebug() << "BPB_NumFATs: " << hex << rf.BPB_NumFATs;
        qDebug() << "BPB_RootEntCnt: " << hex << rf.BPB_RootEntCnt;
        qDebug() << "BPB_TotSec16: " << hex << rf.BPB_TotSec16;
        qDebug() << "BPB_Media: " << hex << rf.BPB_Media;
        qDebug() << "BPB_FATSz16: " << hex << rf.BPB_FATSz16;
        qDebug() << "BPB_SecPerTrk: " << hex << rf.BPB_SecPerTrk;
        qDebug() << "BPB_NumHeads: " << hex << rf.BPB_NumHeads;
        qDebug() << "BPB_HiddSec: " << hex << rf.BPB_HiddSec;
        qDebug() << "BPB_TotSec32: " << hex << rf.BPB_TotSec32;
        qDebug() << "BS_DrvNum: " << hex << rf.BS_DrvNum;
        qDebug() << "BS_Reserved1: " << hex << rf.BS_Reserved1;
        qDebug() << "BS_BootSig: " << hex << rf.BS_BootSig;
        qDebug() << "BS_VolID: " << hex << rf.BS_VolID;
        qDebug() << "BS_VolLab: " << rf.BS_VolLab;
        qDebug() << "BS_FileSysType: " << rf.BS_FileSysType;

        file.seek(510);

        uchar b510 = 0;
        uchar b511 = 0;

        in.readRawData(reinterpret_cast<char*>(&b510), sizeof(b510));
        in.readRawData(reinterpret_cast<char*>(&b511), sizeof(b511));

        qDebug() << "Byte 510: " << hex << b510;
        qDebug() << "Byte 511: " << hex << b511;
    }

    file.close();
}

int main(int argc, char *argv[])
{
    QCoreApplication a(argc, argv);

    Fat12Header f12;

    PrintHeader(f12, "E:\\data.img");
    
    return a.exec();
}
