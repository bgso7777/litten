package com.litten.common.util;

import com.litten.Constants;
import com.litten.common.config.Config;
import com.litten.common.dynamic.BeanUtil;
import lombok.extern.log4j.Log4j2;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.JavaMailSenderImpl;
import org.springframework.mail.javamail.MimeMessageHelper;

import java.io.UnsupportedEncodingException;
import java.util.Date;
import java.util.Properties;

import jakarta.activation.CommandMap;
import jakarta.activation.MailcapCommandMap;
import jakarta.mail.*;
import jakarta.mail.internet.*;

@Log4j2
public class Mailer {

	JavaMailSenderImpl javaMailSender = null;

	private String host;
	private String port;
	private String id;
	private String password;
	private String name;
	private String sender;

	public Mailer() {
//		host=Config.getInstance().getSmtpHost();
//		port=Config.getInstance().getSmtpPort();
//		id=Config.getInstance().getSmtpId();
//		password=Config.getInstance().getSmtpPassword();

//		host = "outlook.office365.com";
//		port = "587";
//		id = "aice@saltlux.com";
//		password = "MsCy9jC4QyceCNS";

		javaMailSender = BeanUtil.getBean2(JavaMailSenderImpl.class);
	}

	public Mailer(String host, String port, String id, String password, String name ) {
		this.host = host;
		this.port = port;
		this.id = id;
		this.password = password;
		this.name = name;
	}

	public void setHost(String host) {
		this.host = host;
	}

	public void setPort(String port) {
		this.port = port;
	}

	public void setId(String id) {
		this.id = id;
	}

	public void setPassword(String password) {
		this.password = password;
	}

	public void setName(String name) {
		this.name = name;
	}

	public void sendRetrieveDnis(String toMail, String dnis, String retrieveDate, String siteLanCd) {

		String from = "company@ploonet.com";
		String subject = "";

		if( siteLanCd==null || siteLanCd.equals(""))
			siteLanCd = "KR";

		if( siteLanCd.equals("KR") )
			subject = "[플루닛] 손비서 전용 번호 회수 안내";
		else if( siteLanCd.equals("EN") )
			subject = "[Ploonet] Handy Secretary AI Assistant Dedicated Number Retrieval Notice";

		StringBuffer content = new StringBuffer();
		content.append(getRetrieveDnisTemplate(dnis, retrieveDate, siteLanCd));

		try {
			MimeMessage mail = javaMailSender.createMimeMessage();
			MimeMessageHelper mailHelper = new MimeMessageHelper(mail, true, "UTF-8");
			mailHelper.setFrom(from);
			mailHelper.setTo(toMail);
			mailHelper.setSubject(subject);
			mailHelper.setText(content.toString(), true);
			javaMailSender.send(mail);
		} catch(Exception e) {
			log.error(e);
		}
	}

	public void sendSignCode(String toMail, String signKey, String siteLanCd) throws Exception {

		String from = "company@ploonet.com";
		String subject = "";

		if( siteLanCd==null || siteLanCd.equals(""))
			siteLanCd = "KR";

		if( siteLanCd.equals("KR") )
			subject = "[플루닛] 로그인 인증번호";
		else if( siteLanCd.equals("EN") )
			subject = "[Ploonet] Login Authentication Code";

		StringBuffer content = new StringBuffer();
		content.append(getSignCodeTemplate(signKey, siteLanCd));

		MimeMessage mail = javaMailSender.createMimeMessage();
		MimeMessageHelper mailHelper = new MimeMessageHelper(mail,true,"UTF-8");
		mailHelper.setFrom(from);
		mailHelper.setTo(toMail);
		mailHelper.setSubject(subject);
		mailHelper.setText(content.toString(), true);
		javaMailSender.send(mail);
	}

	public void sendChangePassword(String toMail, String toName,String toUrl, String requestIp) throws Exception {

		int mm = Constants.CHANGE_PASSWORD_DUE_MINUTE/60;

		String from = "aice@saltlux.com";
		String subject = "계정의 비밀번호 재설정 요청을 하셨습니다.";
		String content = "비밀번호를 재설정할까요?<p>";
			   content += toName+"("+toMail+")님 계정에 대해 비밀번호 재설정을 요청하신 경우 아래 비밀번호 재설정을 진행하세요.("+mm+"분 이내)<p>";
//			   content += "본인의 요청이 아닌 경우 다이퀘스트 고객센터로 연락 바랍니다.<p><p>";
		       content += "<a href=\""+toUrl+"\">비밀번호 재설정</a>";

		MimeMessage mail = javaMailSender.createMimeMessage();
		MimeMessageHelper mailHelper = new MimeMessageHelper(mail,true,"UTF-8");
		mailHelper.setFrom(from);
		mailHelper.setTo(toMail);
		mailHelper.setSubject(subject);
		mailHelper.setText(content, true);
		javaMailSender.send(mail);
	}

	public void completeChangePassword(String toMail, String toName) throws Exception {

		String from = "aice@saltlux.com";
		String subject = "다이퀘스트 계정의 비밀번호를 재설정 했습니다.";
		String content = toName+"("+toMail+")님 계정에 대해 비밀번호 재설정을 완료 하였습니다.<p>";
			   content += "새로운 비밀번호로 사용 하시기 바랍니다.<p>";
			   content += "본인의 요청이 아닌 경우 다이퀘스트 고객센터로 연락 바랍니다. ";

		MimeMessage mail = javaMailSender.createMimeMessage();
		MimeMessageHelper mailHelper = new MimeMessageHelper(mail,true,"UTF-8");
		mailHelper.setFrom(from);
		mailHelper.setTo(toMail);
		mailHelper.setSubject(subject);
		mailHelper.setText(content, true);
		javaMailSender.send(mail);
	}

	public void sendDeveloper(String title, String content) throws Exception {
		try {
			String from = javaMailSender.getUsername();
			String toMail = Config.getInstance().getDeveloperMail();
			MimeMessage mail = javaMailSender.createMimeMessage();
			MimeMessageHelper mailHelper = new MimeMessageHelper(mail, true, "UTF-8");
			mailHelper.setFrom(from);
			mailHelper.setTo(toMail);
			mailHelper.setSubject(title);
			mailHelper.setText(content, true);
			javaMailSender.send(mail);
		} catch(Exception e) {
			e.printStackTrace();
		}
	}

	public void sendMail(String subject, String content, String toEmail, String charSet) throws UnsupportedEncodingException, MessagingException {

		try {
			//String bodyEncoding = "UTF-8"; //콘텐츠 인코딩

			StringBuffer sb = new StringBuffer();
			sb.append(content);
			String html = sb.toString();

			// 메일 옵션 설정
			Properties props = new Properties();
			props.put("mail.transport.protocol", "smtp");
			props.put("mail.smtp.host", host);
			props.put("mail.smtp.port", port);
			props.put("mail.smtp.auth", "true");

			props.put("mail.smtp.quitwait", "false");
			props.put("mail.smtp.socketFactory.port", port);
			props.put("mail.smtp.socketFactory.class", "javax.net.ssl.SSLSocketFactory");
			//props.put("mail.smtp.ssl.protocols", "TLSv1.2");
			props.put("mail.smtp.ssl.enable", "true");
			props.put("mail.smtp.socketFactory.fallback", "false");

			// 메일 서버  인증 계정 설정
			Authenticator auth = new Authenticator() {
				protected PasswordAuthentication getPasswordAuthentication() {
					return new PasswordAuthentication(id,password);
				}
			};

			// 메일 세션 생성
			Session session = Session.getInstance(props, auth);

			// 메일 송/수신 옵션 설정
			Message message = new MimeMessage(session);
			message.setFrom(new InternetAddress(id,name));
			message.setRecipients(MimeMessage.RecipientType.TO, InternetAddress.parse(toEmail, false));
			message.setSubject(subject);
			message.setSentDate(new Date());

			// 메일 콘텐츠 설정
			Multipart mParts = new MimeMultipart();
			MimeBodyPart mTextPart = new MimeBodyPart();
			MimeBodyPart mFilePart = null;

			// 메일 콘텐츠 - 내용
			mTextPart.setText(html, charSet, "html");
			mParts.addBodyPart(mTextPart);

			// 메일 콘텐츠 설정
			message.setContent(mParts);

			// MIME 타입 설정
			MailcapCommandMap MailcapCmdMap = (MailcapCommandMap) CommandMap.getDefaultCommandMap();
			MailcapCmdMap.addMailcap("text/html;; x-java-content-handler=com.sun.mail.handlers.text_html");
			MailcapCmdMap.addMailcap("text/xml;; x-java-content-handler=com.sun.mail.handlers.text_xml");
			MailcapCmdMap.addMailcap("text/plain;; x-java-content-handler=com.sun.mail.handlers.text_plain");
			MailcapCmdMap.addMailcap("multipart/*;; x-java-content-handler=com.sun.mail.handlers.multipart_mixed");
			MailcapCmdMap.addMailcap("message/rfc822;; x-java-content-handler=com.sun.mail.handlers.message_rfc822");
			CommandMap.setDefaultCommandMap(MailcapCmdMap);

			// 메일 발송
			Transport.send( message );
		} catch(Exception e) {
			e.printStackTrace();
		}
	}

	/**
	 *
	 * @param to
	 * @param subject
	 * @param content
	 * @throws Exception
	 */
	public void sendExchangeServer(String to, String subject, String content, String charSet) throws Exception {

		Properties props = System.getProperties();
		props.setProperty("mail.transport.protocol", "smtp");
		props.setProperty("mail.smtp.host", host);
		props.setProperty("mail.smtp.user", id);
		props.setProperty("mail.smtp.password", password);
		props.setProperty("mail.smtp.port", port);
		props.setProperty("mail.smtp.auth", "true");
		props.setProperty("mail.smtp.ehlo", "false");
		props.setProperty("mail.debug", "true");

		props.setProperty("smtp.auth.plain.disable", "false");
		props.setProperty("mail.smtp.auth", "true");
		props.setProperty("mail.smtp.starttls.enable", "true");

		/*

Configure the js.quartz.properties with the respective values to connect to your Office 365 SMTP. For example:

report.scheduler.mail.sender.host=smtp.office365.com
report.scheduler.mail.sender.username=<address>@someaddress.com
report.scheduler.mail.sender.password=<password>
report.scheduler.mail.sender.from=<address>@someaddress.com
report.scheduler.mail.sender.protocol=smtp
report.scheduler.mail.sender.port=587
report.scheduler.mail.smtp.starttls.enable=true
report.scheduler.mail.smtp.auth=true

The following properties need to be appended to javaMail bean of applicationContext.xml and applicationContext-report-scheduling.xml:
mail.smtp.auth=true
mail.smtp.starttls.enable=true

mail.sender.protocol needs to be SMTP


		 */


		Session session = Session.getDefaultInstance(props, null);
		MimeMessage message = new MimeMessage(session);

		//message.setFrom(new InternetAddress(from));
		message.setFrom(new InternetAddress(id));

		InternetAddress to_address = new InternetAddress(to);
		message.addRecipient(Message.RecipientType.TO, to_address);

		if(charSet.equals("")) {
			message.setSubject(subject);
			message.setText(content);
		} else {
			message.setSubject(subject, charSet);
			message.setText(content, charSet);
		}

		Transport transport = session.getTransport("smtp");
		transport.connect(host, id, password);
		transport.sendMessage(message, message.getAllRecipients());
		transport.close();
	}

	public static void main(String argv[]) {
		Mailer mailer = new Mailer();
		mailer.testSendMail();
	}


	public void testSendMail2(String to) throws Exception {

		JavaMailSenderImpl javaMailSender = BeanUtil.getBean2(JavaMailSenderImpl.class);

		String subject = "password change mail";
		String content = "password : <p> new password : ";
		String from = "aice@saltlux.com";
//		String to = "byoungkyu.so@saltlux.com";

		try {

//			MailerAuthentication mailerAuthentication = new MailerAuthentication();

//Session session1 = javaMailSender.getSession();
//Session session = Session.getInstance(javaMailSender.getJavaMailProperties(),mailerAuthentication);

//			Authenticator auth = new Authenticator() {
//				protected PasswordAuthentication getPasswordAuthentication() {
//					return new PasswordAuthentication(javaMailSender.getUsername(), javaMailSender.getPassword());
//				}
//			};
//
//			javaMailSender.getJavaMailProperties().setProperty("mail.smtp.socketFactory.class", "javax.net.ssl.SSLSocketFactory");
//			javaMailSender.getJavaMailProperties().setProperty("mail.smtp.socketFactory.fallback", "false");
//			javaMailSender.getJavaMailProperties().setProperty("mail.smtp.socketFactory.port", String.valueOf(javaMailSender.getPort()));
//
//			Session session = Session.getInstance(javaMailSender.getJavaMailProperties(), auth);
//			javaMailSender.setSession(session);

			MimeMessage mail = javaMailSender.createMimeMessage();
			MimeMessageHelper mailHelper = new MimeMessageHelper(mail,true,"UTF-8");
			// true는 멀티파트 메세지를 사용하겠다는 의미

			/*
			 * 단순한 텍스트 메세지만 사용시엔 아래의 코드도 사용 가능
			 * MimeMessageHelper mailHelper = new MimeMessageHelper(mail,"UTF-8");
			 */

			mailHelper.setFrom(from);
			// 빈에 아이디 설정한 것은 단순히 smtp 인증을 받기 위해 사용 따라서 보내는이(setFrom())반드시 필요
			// 보내는이와 메일주소를 수신하는이가 볼때 모두 표기 되게 원하신다면 아래의 코드를 사용하시면 됩니다.
			//mailHelper.setFrom("보내는이 이름 <보내는이 아이디@도메인주소>");
			mailHelper.setTo(to);
			mailHelper.setSubject(subject);
			mailHelper.setText(content, true);
			javaMailSender.send(mail);

		} catch(Exception e) {
			e.printStackTrace();
		}
	}

	public JavaMailSender testSendMail() {
		JavaMailSenderImpl javaMailSender = new JavaMailSenderImpl();
		try {

//			case "mail.smtp.host":
//			javaMailSender.setHost("outlook.office365.com");
			javaMailSender.setHost("smtp.office365.com");
//			case "mail.smtp.port":
			javaMailSender.setPort(587);
//			case "mail.smtp.user":
//			javaMailSender.setUsername("aice@saltlux.com");
			javaMailSender.setUsername("byoungkyu.so@saltlux.com");
//			case "mail.smtp.password":
//			javaMailSender.setPassword("MsCy9jC4QyceCNS");
			javaMailSender.setPassword("zaq1!@2wsxN");

			Properties javaMailProperties = new Properties();
			javaMailProperties.setProperty("mail.transport.protocol", "smtps");
			javaMailProperties.setProperty("mail.smtp.host", "smtp.office365.com");
			javaMailProperties.setProperty("mail.smtp.user", "byoungkyu.so@saltlux.com");
			javaMailProperties.setProperty("mail.smtp.password", "zaq1!@2wsxN");
			javaMailProperties.setProperty("mail.smtp.port", "587");
//			javaMailProperties.setProperty("mail.smtp.auth", "true");
//			javaMailProperties.setProperty("mail.smtp.ehlo", "false");
			javaMailProperties.setProperty("mail.debug", "true");
//			javaMailProperties.setProperty("smtp.auth.plain.disable", "false");
//			javaMailProperties.setProperty("mail.smtp.auth", "true");
			javaMailProperties.setProperty("mail.smtp.starttls.enable", "true");
//			javaMailProperties.setProperty("mail.smtp.ssl.enable", "true");
			javaMailProperties.setProperty("mail.smtp.ssl.protocols", "TLSv1.2");


			javaMailSender.setJavaMailProperties(javaMailProperties);

			Authenticator auth = new Authenticator() {
				protected PasswordAuthentication getPasswordAuthentication() {
					return new PasswordAuthentication(javaMailSender.getUsername(), javaMailSender.getPassword());
				}
			};

			Session session = Session.getInstance(javaMailSender.getJavaMailProperties(), auth);
			javaMailSender.setSession(session);

			MimeMessage message = javaMailSender.createMimeMessage();
			MimeMessageHelper messageHelper = new MimeMessageHelper(message,true,"utf-8");
			messageHelper.setTo("byoungkyu.so@saltlux.com");
			messageHelper.setSubject("password change mail");
			messageHelper.setText("password, new password");
			javaMailSender.send(message);

		}catch(Exception e1) {
			e1.printStackTrace();
		}
		return javaMailSender;
	}


	private String getSignCodeTemplate(String signKey, String siteLanCd) {

		StringBuffer emailTemplate = new StringBuffer();

		emailTemplate.append("<!DOCTYPE html><html><head>");
		emailTemplate.append("<meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\"><title>PLOONET</title>");
		emailTemplate.append("<style>");
		emailTemplate.append("/* * {border:0px solid #f00} */");
		emailTemplate.append("</style>");
		emailTemplate.append("</head>");
		emailTemplate.append("<body style=\"width:100%;margin:0;padding:0;background:#f2f4f5;\">");
		emailTemplate.append("");
		emailTemplate.append("<table border=\"0\" cellpadding=\"0\" cellspacing=\"0\" style=\"outline: 0; width: 100%; min-width: 100%; height: 100%;font-family: Helvetica, Arial, sans-serif; line-height: 24px; font-weight: normal; font-size: 16px;color: #000000; margin: 0; padding: 0;\" bgcolor=\"#ffffff\">");
		emailTemplate.append("<tbody>");
		emailTemplate.append("<tr>");
		emailTemplate.append("    <td valign=\"top\" style=\"line-height: 24px; font-size: 16px; margin: 0;\" align=\"center\">");
		emailTemplate.append("        <div style=\"padding-top: 50px; padding-bottom: 50px; background-color: #f9f9f9;\" align=\"center\">");
		emailTemplate.append("            <div style=\"width: 700px; border-radius: 10px; background-color: #fff; overflow: hidden; border: 1px solid #dcdcdc;\">");
		emailTemplate.append("                <div style=\"padding:22px 22px;border-bottom-width: 1px; border-bottom-color: #eaeaea; border-bottom-style: solid;text-align:left;\">");
		emailTemplate.append("                    <img src=https://www.ploonet.com/mail/logo_ploonet_header.png alt=\"Ploonet\" style=\"height: auto; line-height: 100%; outline: none; text-decoration: none; display: block; border-style: none; border-width: 0;\">");
		emailTemplate.append("                </div>");
		emailTemplate.append("                <div style=\"padding: 0 40px;\">");
		emailTemplate.append("                <!-- 콘텐츠 영역 // start -->");
		emailTemplate.append("");
		emailTemplate.append("  <!-- 콘텐츠 영역 // start -->");
		emailTemplate.append("      <div style=\"padding-top: 30px; font-size: 24px; font-weight: bold; color: #222;line-height:34px;\" align=\"left\">");
		if( siteLanCd.equals("KR") ) {
			emailTemplate.append("          이메일 인증을 진행해 주세요.");
		} else {
			emailTemplate.append("          Please proceed with email verification.");
		}
		emailTemplate.append("      </div>");
		emailTemplate.append("      <div style=\"padding-top: 20px; padding-bottom: 20px; font-size: 16px; color: #666;line-height:30px;\" align=\"left\">");
		if( siteLanCd.equals("KR") ) {
			emailTemplate.append("          플루닛 회원가입을 위해 이메일 인증번호가 발급되었습니다.<br>");
			emailTemplate.append("          아래의 인증번호 6자리를 진행 중인 화면에 입력하고 인증을 완료해주세요.<br>");
			emailTemplate.append("          <span style=\"font-weight:bold;\">인증번호는 이메일 발송 시점으로부터 10분간만 유효합니다.</span><br>");
		} else {
			emailTemplate.append("          An email verification code has been issued for your Plunit account registration.<br>");
			emailTemplate.append("          Please enter the 6-digit verification code below into the ongoing screen to complete the verification process.<br>");
			emailTemplate.append("          <span style=\"font-weight:bold;\">The verification code is valid for 10 minutes from the time the email was sent.</span><br>");
		}
		emailTemplate.append("      </div>");
		emailTemplate.append("      <div style=\"width:640px;text-align:left;\">");
		if( siteLanCd.equals("KR") ) {
			emailTemplate.append("          <h4>인증코드</h4>");
		} else {
			emailTemplate.append("          <h4>Verification Code</h4>");
		}
		emailTemplate.append("          <table style=\"width: 98%; table-layout: fixed;background:#F8F7F8;border-radius:15px;\" border=\"0\" cellpadding=\"0\" cellspacing=\"0\">");
		emailTemplate.append("              <tbody>");
		emailTemplate.append("              <tr style=\"height: 40px;\">");
		emailTemplate.append("                  <td style=\"height:40px;padding-left: 20px;padding-top:10px;line-height: 40px; font-size: 24px; margin: 0;font-weight:bold;\" align=\"left\">");
		emailTemplate.append("                      <span>"+signKey+"</span>");
		emailTemplate.append("                  </td>");
		emailTemplate.append("              </tr>");
		emailTemplate.append("              </tbody>");
		emailTemplate.append("          </table>");
		emailTemplate.append("      </div>");
		emailTemplate.append("  <!-- 콘텐츠 영역 // end -->");
		emailTemplate.append("");
		emailTemplate.append("                <!-- 콘텐츠 영역 // end -->");
		emailTemplate.append("                    <div style=\"margin-top:15px;margin-bottom:20px;padding:10px 0px; font-size: 12px; color: #999; border-top:1px solid #000\" align=\"left\">");
		if( siteLanCd.equals("KR") ) {
			emailTemplate.append("                        * 본 메일은 발신 전용 메일이며 회신이 불가능합니다.");
		} else {
			emailTemplate.append("                        * This email is sent from a no-reply address and replies are not possible.");
		}
		emailTemplate.append("                    </div>");
		emailTemplate.append("                </div>");
		emailTemplate.append("                <div style=\"width:100%;height:180px;background-color: #000000; font-size: 12px; color: #bbb; padding: 30px 20px 20px 30px;\" align=\"left\">");
		emailTemplate.append("                    <img src=https://www.ploonet.com/mail/logo_ploonet_footer.png alt=\"Ploonet\" style=\"height: auto; outline: none; text-decoration: none; display: block; border-style: none; border-width: 0;\"><br>");
		if( siteLanCd.equals("KR") ) {
			emailTemplate.append("                    <p style=\"font-weight:bold;font-size:14px;color: #ddd;\">플루닛 고객센터   대표번호 : 1533-6116  |  이메일 주소 : support@ploonet.com</p>");
			emailTemplate.append("                    <p style=\"font-size:12px;color: #999999;\">(주)다이퀘스트  |  사업자등록번호 : 105-86-08825  |  통신판매허가번호 : 2022-서울강남-06647  |  대표이사 : 김경선, 전승훈 </p>");
			emailTemplate.append("                    <p style=\"font-size:12px;color: #999999;\">서울특별시 송파구 올림픽로35길 123, 향군타워 9층 [05510, (구)신천동 7-29] | <a href=https://www.ploonet.com target=\"_ploonet\" style=\"color:#fff\">https://www.ploonet.com</a></p>");
		} else {
			emailTemplate.append("                    <p style=\"font-weight:bold;font-size:14px;color: #ddd;\"> DIQUEST Customer Service Main Contact Number : 1533-6116  |  Email : support@ploonet.com</p>");
			emailTemplate.append("                    <p style=\"font-size:12px;color: #999999;\">PLOONET  |  Business Registration Number : 105-86-08825  |  Telecommunication Sales Permit Number : 2022-서울강남-06647  |  CEO : Kim Kyung-sun, Jeon Seung-hoon </p>");
			emailTemplate.append("                    <p style=\"font-size:12px;color: #999999;\">[05510, (former) Sincheon-dong 7-29] 9th floor of Hyanggun Tower, 123, Olympic-ro 35-gil, Songpa-gu, Seoul, Korea | <a href=https://www.ploonet.com target=\"_ploonet\" style=\"color:#fff\">https://www.ploonet.com</a></p>");
		}
		emailTemplate.append("                    <p style=\"font-size:12px;color: #999999;\">ⓒ 2025 DIQUEST. All rights reserved.</p>");
		emailTemplate.append("                </div>");
		emailTemplate.append("            </div>");
		emailTemplate.append("        </div>");
		emailTemplate.append("    </td>");
		emailTemplate.append("</tr>");
		emailTemplate.append("</tbody>");
		emailTemplate.append("</table>");
		emailTemplate.append("</body>");
		emailTemplate.append("</html>");

		return emailTemplate.toString();
	}

	private String getRetrieveDnisTemplate(String dnis, String retrieveDate, String siteLanCd) {

		StringBuffer emailTemplate = new StringBuffer();

		emailTemplate.append("<!DOCTYPE html>");
		emailTemplate.append("<html>");
		emailTemplate.append("");
		emailTemplate.append("<head>");
		emailTemplate.append("    <meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\">");
		emailTemplate.append("    <title>PLOONET</title>");
		emailTemplate.append("    <style>");
		emailTemplate.append("        /* * {border:0px solid #f00} */");
		emailTemplate.append("    </style>");
		emailTemplate.append("</head>");
		emailTemplate.append("");
		emailTemplate.append("<body style=\"width:100%;margin:0;padding:0;background:#f2f4f5;\">");
		emailTemplate.append("    <table border=\"0\" cellpadding=\"0\" cellspacing=\"0\"");
		emailTemplate.append("        style=\"outline: 0; width: 100%; min-width: 100%; height: 100%;font-family: Helvetica, Arial, sans-serif; line-height: 24px; font-weight: normal; font-size: 16px;color: #000000; margin: 0; padding: 0;\"");
		emailTemplate.append("        bgcolor=\"#ffffff\">");
		emailTemplate.append("        <tbody>");
		emailTemplate.append("            <tr>");
		emailTemplate.append("                <td valign=\"top\" style=\"line-height: 24px; font-size: 16px; margin: 0;\" align=\"center\">");
		emailTemplate.append("                    <div style=\"padding-top: 50px; padding-bottom: 50px; background-color: #f9f9f9;\" align=\"center\">");
		emailTemplate.append("                        <div");
		emailTemplate.append("                            style=\"width: 700px; border-radius: 10px; background-color: #fff; overflow: hidden; border: 1px solid #dcdcdc;\">");
		emailTemplate.append("                            <div");
		emailTemplate.append("                                style=\"padding:22px 22px;border-bottom-width: 1px; border-bottom-color: #eaeaea; border-bottom-style: solid;text-align:left;\">");
		emailTemplate.append("                                <img src=\"https://www.ploonet.com/mail/logo_ploonet_header.png\" alt=\"Ploonet\"");
		emailTemplate.append("                                    style=\"height: auto; line-height: 100%; outline: none; text-decoration: none; display: block; border-style: none; border-width: 0;\">");
		emailTemplate.append("                            </div>");
		emailTemplate.append("                            <div style=\"padding: 0 40px;\">");
		emailTemplate.append("                                <!-- 콘텐츠 영역 // start -->");
		emailTemplate.append("                                <div style=\"padding-top: 30px; font-size: 24px; font-weight: bold; color: #222;line-height:34px;\"");
		emailTemplate.append("                                    align=\"left\">");
		emailTemplate.append("                                    [알림] 손비서 AI 비서 번호 회수 안내");
		emailTemplate.append("                                </div>");
		emailTemplate.append("                                <div style=\"padding-top: 20px; padding-bottom: 9px; font-size: 15px; color: #666;line-height:1.8;\"");
		emailTemplate.append("                                    align=\"left\">");
		emailTemplate.append("                                    <p style=\"margin-bottom: 8px;\">안녕하세요. 손비서입니다.</p>");
		emailTemplate.append("                                    손비서 이용약관 제8조에 따라, 최근 3개월 동안 사용 기록이 없는 전화번호는 <br />자동 회수 대상이 됩니다.<br>");
		emailTemplate.append("                                    <p style=\"margin-bottom: 8px;\">이에 따라 고객님께서 보유하셨던 손비서 번호가 회수되었음을 안내드립니다.</p>");
		emailTemplate.append("                                </div>");
		emailTemplate.append("                                <div style=\"padding: 1px 0px 5px 14px;\">");
		emailTemplate.append("                                    <h4 style=\"text-align:left;line-height: 0.4;\">• 회수 번호 : "+dnis+"</h4>");
		emailTemplate.append("                                    <h4 style=\"text-align:left;line-height: 0.4;\">• 회수 일자 : "+retrieveDate+"</h4>");
		emailTemplate.append("                                </div>");
		emailTemplate.append("                                <span style=\"display: block; padding-top: 10px; color: #666; font-size: 15px; text-align:left;\">");
		emailTemplate.append("                                    번호가 회수됨에 따라 해당 번호로의 손비서 서비스 이용이 불가합니다.<br>");
		emailTemplate.append("                                    계속해서 손비서 서비스를 이용하시려면 [1:1 문의글 남기기]를 통해 말씀해주세요.<br><br>");
		emailTemplate.append("                                    궁금한 사항이 있으시면 언제든지 문의해 주세요.<br><br>");
		emailTemplate.append("                                    감사합니다.<br>");
		emailTemplate.append("                                    손비서 팀 드림");
		emailTemplate.append("                                </span>");
		emailTemplate.append("                                <!-- 콘텐츠 영역 // end -->");
		emailTemplate.append("                                <div style=\"margin-top:15px;margin-bottom:20px;padding:10px 0px; font-size: 12px; color: #999; border-top:1px solid #000\"");
		emailTemplate.append("                                    align=\"left\">");
		emailTemplate.append("                                    * 본 메일은 발신 전용 메일이며 회신이 불가능합니다.");
		emailTemplate.append("                                </div>");
		emailTemplate.append("                            </div>");
		emailTemplate.append("                            <div style=\"width:100%;height:180px;background-color: #000000; font-size: 12px; color: #bbb; padding: 30px 20px 20px 30px;\"");
		emailTemplate.append("                                align=\"left\">");
		emailTemplate.append("                                <img src=\"https://www.ploonet.com/mail/logo_ploonet_footer.png\" alt=\"Ploonet\"");
		emailTemplate.append("                                    style=\"height: auto; outline: none; text-decoration: none; display: block; border-style: none; border-width: 0;\"><br>");
		emailTemplate.append("                                <p style=\"font-weight:bold;font-size:14px;color: #ddd;\">플루닛 고객센터 대표번호 : 1533-6116 | 이메일");
		emailTemplate.append("                                    주소 : support@ploonet.com</p>");
		emailTemplate.append("                                <p style=\"font-size:12px;color: #999999;\">(주)다이퀘스트 | 사업자등록번호 : 105-86-08825 | 통신판매허가번호 :");
		emailTemplate.append("                                    2022-서울강남-06647 | 대표이사 : 김경선, 전승훈 </p>");
		emailTemplate.append("                                <p style=\"font-size:12px;color: #999999;\">서울특별시 송파구 올림픽로35길 123, 향군타워 9층 [05510, (구)신천동 7-29] | <a");
		emailTemplate.append("                                        href=\"https://www.ploonet.com\" target=\"_ploonet\"");
		emailTemplate.append("                                        style=\"color:#fff\">https://www.ploonet.com</a></p>");
		emailTemplate.append("                                <p style=\"font-size:12px;color: #999999;\">ⓒ 2025 DIQUEST. All rights reserved.</p>");
		emailTemplate.append("                            </div>");
		emailTemplate.append("                        </div>");
		emailTemplate.append("                    </div>");
		emailTemplate.append("                </td>");
		emailTemplate.append("            </tr>");
		emailTemplate.append("        </tbody>");
		emailTemplate.append("    </table>");
		emailTemplate.append("</body>");
		emailTemplate.append("");
		emailTemplate.append("</html>");

		return emailTemplate.toString();
	}
}
