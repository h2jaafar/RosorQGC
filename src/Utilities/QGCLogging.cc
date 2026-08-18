#include "QGCLogging.h"
#include "AppSettings.h"
#include "QGCApplication.h"
#include "QGCLoggingCategory.h"
#include "SettingsManager.h"

#include <QtConcurrent/QtConcurrentRun>
#include <QtCore/QDateTime>
#include <QtCore/QDir>
#include <QtCore/QGlobalStatic>
#include <QtCore/QStandardPaths>
#include <QtCore/QStringListModel>
#include <QtCore/QTextStream>

#include <csignal>
#include <cstdio>
#include <cstring>
#include <fcntl.h>
#include <inttypes.h>
#include <sys/ucontext.h>
#include <unistd.h>
#include <unwind.h>

QGC_LOGGING_CATEGORY(QGCLoggingLog, "Utilities.QGCLogging")

Q_GLOBAL_STATIC(QGCLogging, _qgcLogging)

static QtMessageHandler defaultHandler = nullptr;

// Path to the persistent crash log file. Cached at startup so the signal
// handler (which must be async-signal-safe) can write to it without doing
// any Qt allocations.
static char _crashLogPath[1024] = {0};

static QString resolveCrashLogPath()
{
    // IMPORTANT: this runs very early in startup, before SettingsManager's
    // Facts are fully initialized — calling AppSettings::savePath() here
    // would null-deref. Use QStandardPaths only (Qt is already up at this
    // point since QGCApplication was constructed before installHandler()).
    //
    // Prefer Downloads because it's adb-pull-able on every Android version,
    // even with scoped storage. Falls back to AppData if Downloads isn't
    // available (e.g. desktop builds).
    QString dir = QStandardPaths::writableLocation(QStandardPaths::DownloadLocation);
    if (dir.isEmpty()) {
        dir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    }
    if (dir.isEmpty()) {
        dir = QStandardPaths::writableLocation(QStandardPaths::TempLocation);
    }
    QDir().mkpath(dir);
    return QDir(dir).absoluteFilePath(QStringLiteral("RosorQGC-last-crash.log"));
}

static void writeCrashEntry(const QString &message)
{
    const QString path = QString::fromLocal8Bit(_crashLogPath);
    QFile f(path.isEmpty() ? resolveCrashLogPath() : path);
    if (f.open(QIODevice::WriteOnly | QIODevice::Append | QIODevice::Text)) {
        QTextStream out(&f);
        out << QDateTime::currentDateTimeUtc().toString(Qt::ISODateWithMs)
            << " FATAL: " << message << '\n';
        f.flush();
        f.close();
    }
}

namespace {

// Async-signal-safe helpers: no allocations, no malloc-heavy stdio.
// snprintf into a fixed buffer is signal-safe on glibc/bionic since it
// doesn't take global locks for the C99-only conversions we use.

struct BacktraceState {
    void  **current;
    void **end;
};

_Unwind_Reason_Code unwindCb(struct _Unwind_Context *ctx, void *arg)
{
    BacktraceState *s = static_cast<BacktraceState *>(arg);
    uintptr_t pc = _Unwind_GetIP(ctx);
    if (pc) {
        if (s->current == s->end) {
            return _URC_END_OF_STACK;
        }
        *s->current++ = reinterpret_cast<void *>(pc);
    }
    return _URC_NO_REASON;
}

void writeCrashLine(int fd, const char *s)
{
    (void) write(fd, s, strlen(s));
}

void writeCrashHex(int fd, uintptr_t v)
{
    char buf[32];
    int n = snprintf(buf, sizeof(buf), "0x%016" PRIxPTR, v);
    if (n > 0) {
        (void) write(fd, buf, static_cast<size_t>(n));
    }
}

} // namespace

extern "C" void _qgcCrashSignalHandler(int signum, siginfo_t *info, void *ucontext)
{
    // Async-signal-safe path: only POSIX I/O + fixed-size buffers.
    if (_crashLogPath[0] == 0) {
        // Path not cached yet; can't recover safely.
        signal(signum, SIG_DFL);
        raise(signum);
        return;
    }

    int fd = open(_crashLogPath, O_WRONLY | O_CREAT | O_APPEND, 0644);
    if (fd >= 0) {
        const char *signame = "UNKNOWN";
        switch (signum) {
            case SIGSEGV: signame = "SIGSEGV"; break;
            case SIGABRT: signame = "SIGABRT"; break;
            case SIGBUS:  signame = "SIGBUS";  break;
            case SIGFPE:  signame = "SIGFPE";  break;
            case SIGILL:  signame = "SIGILL";  break;
            case SIGPIPE: signame = "SIGPIPE"; break;
        }

        writeCrashLine(fd, "\n*** CRASH signal=");
        writeCrashLine(fd, signame);
        writeCrashLine(fd, " ***\n");

        // Fault address (SIGSEGV / SIGBUS): where did the deref go wrong?
        if (info) {
            writeCrashLine(fd, "  fault_addr=");
            writeCrashHex(fd, reinterpret_cast<uintptr_t>(info->si_addr));
            writeCrashLine(fd, "\n");
        }

        // Program counter at time of crash (arm64 mcontext).
#if defined(__aarch64__)
        if (ucontext) {
            const ucontext_t *uc = static_cast<const ucontext_t *>(ucontext);
            writeCrashLine(fd, "  pc=");
            writeCrashHex(fd, static_cast<uintptr_t>(uc->uc_mcontext.pc));
            writeCrashLine(fd, "  lr=");
            writeCrashHex(fd, static_cast<uintptr_t>(uc->uc_mcontext.regs[30]));
            writeCrashLine(fd, "\n");
        }
#else
        (void) ucontext;
#endif

        // Stack trace via _Unwind_Backtrace (available in libunwind /
        // libgcc, works fine in signal handlers in practice — same
        // approach used by Breakpad and sentry-native).
        void *frames[32];
        BacktraceState st = { frames, frames + 32 };
        _Unwind_Backtrace(unwindCb, &st);
        int nFrames = static_cast<int>(st.current - frames);
        writeCrashLine(fd, "  backtrace (");
        {
            char n[16];
            int m = snprintf(n, sizeof(n), "%d", nFrames);
            if (m > 0) (void) write(fd, n, static_cast<size_t>(m));
        }
        writeCrashLine(fd, " frames):\n");
        for (int i = 0; i < nFrames; ++i) {
            writeCrashLine(fd, "    #");
            {
                char n[8];
                int m = snprintf(n, sizeof(n), "%02d ", i);
                if (m > 0) (void) write(fd, n, static_cast<size_t>(m));
            }
            writeCrashHex(fd, reinterpret_cast<uintptr_t>(frames[i]));
            writeCrashLine(fd, "\n");
        }

        (void) fsync(fd);
        (void) close(fd);
    }

    // Re-raise so Android still produces a tombstone / proper process exit.
    signal(signum, SIG_DFL);
    raise(signum);
}

static void msgHandler(QtMsgType type, const QMessageLogContext &context, const QString &msg)
{
    // Format the message using Qt's pattern
    const QString message = qFormatLogMessage(type, context, msg);

    // For fatal messages, persist BEFORE the abort() that Qt is about to call,
    // so we don't lose the actual reason in the upcoming process death.
    if (type == QtFatalMsg) {
        writeCrashEntry(message);
    }

    // Filter out Qt Quick internals
    if (QGCLogging::instance() && !QString(context.category).startsWith("qt.quick")) {
        QGCLogging::instance()->log(message);
    }

    // Call the previous handler if it exists
    if (defaultHandler) {
        defaultHandler(type, context, msg);
    }
}

QGCLogging *QGCLogging::instance()
{
    return _qgcLogging();
}

QGCLogging::QGCLogging(QObject *parent)
    : QStringListModel(parent)
{
    qCDebug(QGCLoggingLog) << this;

    _flushTimer.setInterval(kFlushIntervalMSecs);
    _flushTimer.setSingleShot(false);
    (void) connect(&_flushTimer, &QTimer::timeout, this, &QGCLogging::_flushToDisk);
    _flushTimer.start();

    // Connect the emitLog signal to threadsafeLog slot
#if defined(Q_OS_ANDROID) || defined(Q_OS_IOS)
    const Qt::ConnectionType conntype = Qt::QueuedConnection;
#else
    const Qt::ConnectionType conntype = Qt::AutoConnection;
#endif
    (void) connect(this, &QGCLogging::emitLog, this, &QGCLogging::_threadsafeLog, conntype);
}

QGCLogging::~QGCLogging()
{
    qCDebug(QGCLoggingLog) << this;
}

void QGCLogging::installHandler()
{
    // Define the format for qDebug/qWarning/etc output
    qSetMessagePattern(QStringLiteral("%{time process}%{if-warning} Warning:%{endif}%{if-critical} Critical:%{endif} %{message} - %{category} - (%{function}:%{line})"));

    // Install our custom handler
    defaultHandler = qInstallMessageHandler(msgHandler);

    // Cache the crash log path into a C string so signal handlers can use it
    // without doing any allocations.
    const QString path = resolveCrashLogPath();
    const QByteArray utf8 = path.toLocal8Bit();
    qstrncpy(_crashLogPath, utf8.constData(), sizeof(_crashLogPath));

    // Note a clean app start in the crash log so we can tell crashes apart.
    QFile marker(path);
    if (marker.open(QIODevice::WriteOnly | QIODevice::Append | QIODevice::Text)) {
        QTextStream out(&marker);
        out << "\n=== START "
            << QDateTime::currentDateTimeUtc().toString(Qt::ISODateWithMs)
            << " pid=" << QCoreApplication::applicationPid()
            << " ===\n";
        marker.close();
    }

    // Native signal handlers so SIGSEGV/SIGABRT leave a breadcrumb on disk.
    struct sigaction sa;
    std::memset(&sa, 0, sizeof(sa));
    sa.sa_sigaction = _qgcCrashSignalHandler;
    sa.sa_flags = SA_RESETHAND | SA_SIGINFO; // run once, then default; also want siginfo + ucontext
    sigemptyset(&sa.sa_mask);
    for (int sig : {SIGSEGV, SIGABRT, SIGBUS, SIGFPE, SIGILL}) {
        (void) sigaction(sig, &sa, nullptr);
    }
}

void QGCLogging::log(const QString &message)
{
    // Emit the signal so threadsafeLog runs in the correct thread
    if (!_ioError) {
        emit emitLog(message);
    }
}

void QGCLogging::_threadsafeLog(const QString &message)
{
    // Notify view of new row
    const int line = rowCount();
    (void) QStringListModel::insertRows(line, 1);
    (void) setData(index(line, 0), message, Qt::DisplayRole);

    // Trim old entries to cap memory usage
    static constexpr const int kMaxLogRows = kMaxLogFileSize / 100;
    if (rowCount() > kMaxLogRows) {
        const int removeCount = rowCount() - kMaxLogRows;
        beginRemoveRows(QModelIndex(), 0, removeCount - 1);
        (void) removeRows(0, removeCount);
        endRemoveRows();
    }

    // Queue for disk flush
    _pendingDiskWrites.append(message);
}

void QGCLogging::_rotateLogs()
{
    // Close the current log
    _logFile.close();

    // Full path without extension
    const QString basePath = _logFile.fileName();    // e.g. "/path/QGCConsole.log"
    const QFileInfo fileInfo(basePath);
    const QString dir = fileInfo.absolutePath();
    const QString name = fileInfo.baseName();        // "QGCConsole"
    const QString ext = fileInfo.completeSuffix();   // "log"

    // Rotate existing backups: QGCConsole.4.log → QGCConsole.5.log, …
    for (int i = kMaxBackupFiles - 1; i >= 1; --i) {
        const QString from = QStringLiteral("%1/%2.%3.%4").arg(dir, name).arg(i).arg(ext);
        const QString to = QStringLiteral("%1/%2.%3.%4").arg(dir, name).arg(i+1).arg(ext);
        if (QFile::exists(to)) {
            (void) QFile::remove(to);
        }
        if (QFile::exists(from)) {
            (void) QFile::rename(from, to);
        }
    }

    // Move the just‐closed log to “.1”
    const QString firstBackup = QStringLiteral("%1/%2.1.%3").arg(dir, name, ext);
    if (QFile::exists(firstBackup)) {
        (void) QFile::remove(firstBackup);
    }
    (void) QFile::rename(basePath, firstBackup);

    // Re‑open a fresh log file
    _logFile.setFileName(basePath);
    if (!_logFile.open(QIODevice::WriteOnly | QIODevice::Append | QIODevice::Text)) {
        _ioError = true;
        qgcApp()->showAppMessage(tr("Unable to reopen log file %1: %2").arg(_logFile.fileName(), _logFile.errorString()));
    }
}

void QGCLogging::_flushToDisk()
{
    if (_pendingDiskWrites.isEmpty() || _ioError) {
        return;
    }

    // Ensure log output enabled and file open
    if (!_logFile.isOpen()) {
        if (!qgcApp()->logOutput()) {
            _pendingDiskWrites.clear();
            return;
        }

        const QString saveDirPath = SettingsManager::instance()->appSettings()->crashSavePath();
        const QDir saveDir(saveDirPath);
        const QString saveFilePath = saveDir.absoluteFilePath("QGCConsole.log");

        _logFile.setFileName(saveFilePath);
        if (!_logFile.open(QIODevice::WriteOnly | QIODevice::Append | QIODevice::Text)) {
            _ioError = true;
            qgcApp()->showAppMessage(tr("Open console log output file failed %1 : %2").arg(_logFile.fileName(), _logFile.errorString()));
            return;
        }
    }

    // Check size before writing
    if (_logFile.size() >= kMaxLogFileSize) {
        _rotateLogs();
    }

    // Write all pending lines
    QTextStream out(&_logFile);
    for (const QString &line : std::as_const(_pendingDiskWrites)) {
        out << line << '\n';
        if (out.status() != QTextStream::Ok) {
            _ioError = true;
            qCWarning(QGCLoggingLog) << "Error writing to log file:" << _logFile.errorString();
            break;
        }
    }
    (void) _logFile.flush();
    _pendingDiskWrites.clear();
}

void QGCLogging::writeMessages(const QString &destFile)
{
    // Snapshot current logs on GUI thread
    const QStringList logs = stringList();

    // Run the file write in a separate thread
    (void) QtConcurrent::run([this, destFile, logs]() {
        emit writeStarted();
        bool success = false;
        QSaveFile file(destFile);
        if (file.open(QIODevice::WriteOnly | QIODevice::Text)) {
            QTextStream out(&file);
            for (const QString &line : logs) {
                out << line << '\n';
            }
            success = ((out.status() == QTextStream::Ok) && file.commit());
        } else {
            qCWarning(QGCLoggingLog) << "write failed:" << file.errorString();
        }
        emit writeFinished(success);
    });
}
