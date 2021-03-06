class Httpd22 < Formula
  homepage "https://httpd.apache.org/"
  url "https://archive.apache.org/dist/httpd/httpd-2.2.29.tar.bz2"
  sha256 "574b4f994b99178dfd5160bcb14025402e2ce381be9889b83e4be0ffbf5839a4"

  conflicts_with "homebrew/apache/httpd24", :because => "different versions of the same software"

  skip_clean :la

  option "with-mpm-worker", "Use the Worker Multi-Processing Module instead of Prefork"
  option "with-mpm-event", "Use the Event Multi-Processing Module instead of Prefork"
  option "with-privileged-ports", "Use the default ports 80 and 443 (which require root privileges), instead of 8080 and 8443"

  depends_on "apr-util"
  depends_on "openssl"
  depends_on "pcre" => :optional
  depends_on "homebrew/dupes/zlib"

  if build.with? "mpm-worker" and build.with? "mpm-event"
    onoe "Cannot build with both worker and event MPMs, choose one"
    exit 1
  end

  def install
    # point config files to opt_prefix instead of the version-specific prefix
    inreplace "Makefile.in",
      '#@@ServerRoot@@#$(prefix)#', '#@@ServerRoot@@'"##{opt_prefix}#"

    # install custom layout
    File.open("config.layout", "w") { |f| f.write(httpd_layout) }

    args = %W[
      --enable-layout=Homebrew
      --enable-mods-shared=all
      --enable-unique-id
      --enable-ssl
      --enable-dav
      --enable-cache
      --enable-proxy
      --enable-logio
      --enable-deflate
      --enable-cgi
      --enable-cgid
      --enable-suexec
      --enable-rewrite
    ]

    args << "--with-apr=#{Formula["apr"].opt_prefix}"
    args << "--with-apr-util=#{Formula["apr-util"].opt_prefix}"
    args << "--with-ssl=#{Formula['openssl'].opt_prefix}"
    args << "--with-z=#{Formula['zlib'].opt_prefix}"

    if build.with? "mpm-worker"
      args << "--with-mpm=worker"
    elsif build.with? "mpm-event"
      args << "--with-mpm=event"
    else
      args << "--with-mpm=prefork"
    end

    if build.with? "privileged-ports"
      args << "--with-port=80"
      args << "--with-sslport=443"
    else
      args << "--with-port=8080"
      args << "--with-sslport=8443"
    end

    if build.with? "ldap"
      args << "--with-ldap"
      args << "--enable-ldap"
      args << "--enable-authnz-ldap"
    end

    args << "--with-pcre=#{Formula['pcre'].opt_prefix}" if build.with? "pcre"

    system "./configure", *args

    system "make"
    system "make install"
    (var/"apache2/log").mkpath
    (var/"apache2/run").mkpath
    touch("#{var}/log/apache2/access_log") unless File.exists?("#{var}/log/apache2/access_log")
    touch("#{var}/log/apache2/error_log") unless File.exists?("#{var}/log/apache2/error_log")
  end

  def plist; <<-EOS.undent
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>Label</key>
      <string>#{plist_name}</string>
      <key>ProgramArguments</key>
      <array>
        <string>#{opt_prefix}/bin/httpd</string>
        <string>-D</string>
        <string>FOREGROUND</string>
      </array>
      <key>RunAtLoad</key>
      <true/>
    </dict>
    </plist>
    EOS
  end

  def httpd_layout
    return <<-EOS.undent
      <Layout Homebrew>
          prefix:        #{prefix}
          exec_prefix:   ${prefix}
          bindir:        ${exec_prefix}/bin
          sbindir:       ${exec_prefix}/bin
          libdir:        ${exec_prefix}/lib
          libexecdir:    ${exec_prefix}/libexec
          mandir:        #{man}
          sysconfdir:    #{etc}/apache2/2.2
          datadir:       #{var}/www
          installbuilddir: ${prefix}/build
          errordir:      ${datadir}/error
          iconsdir:      ${datadir}/icons
          htdocsdir:     ${datadir}/htdocs
          manualdir:     ${datadir}/manual
          cgidir:        #{var}/apache2/cgi-bin
          includedir:    ${prefix}/include/apache2
          localstatedir: #{var}/apache2
          runtimedir:    #{var}/run/apache2
          logfiledir:    #{var}/log/apache2
          proxycachedir: ${localstatedir}/proxy
      </Layout>
      EOS
  end

  test do
    system sbin/"httpd", "-v"
  end

  def caveats
    if build.with? "privileged-ports"
      <<-EOS.undent
      To load #{name} when --with-privileged-ports is used:
          sudo cp -v #{plist_path} /Library/LaunchDaemons
          sudo chown -v root:wheel /Library/LaunchDaemons/#{plist_path.basename}
          sudo chmod -v 644 /Library/LaunchDaemons/#{plist_path.basename}
          sudo launchctl load /Library/LaunchDaemons/#{plist_path.basename}

      To reload #{name} after an upgrade when --with-privileged-ports is used:
          sudo launchctl unload /Library/LaunchDaemons/#{plist_path.basename}
          sudo launchctl load /Library/LaunchDaemons/#{plist_path.basename}

      If not using --with-privileged-ports, use the instructions below.
      EOS
    end
  end
end
