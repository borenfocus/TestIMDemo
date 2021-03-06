//
//  BRChatViewController.m
//  TestIMDemo
//
//  Created by 任波 on 2017/7/25.
//  Copyright © 2017年 renb. All rights reserved.
//

#import "BRChatViewController.h"
#import "BRChatCell.h"
#import "BRTimeCell.h"
#import "EMCDDeviceManager.h"
#import "NSDate+BRAdd.h"
#import "BRVoicePlayTool.h"

@interface BRChatViewController ()<UITableViewDataSource, UITableViewDelegate, UITextViewDelegate, EMChatManagerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate>
{
    NSString *_lastTimeStr;
}
/** 输入toolBar底部的约束 */
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *toolBarBottomLayoutConstraint;
/** 输入toolBar高度的约束 */
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *toolBarHeightLayoutConstraint;
@property (weak, nonatomic) IBOutlet UITableView *tableView;
/** textView 输入框 */
@property (weak, nonatomic) IBOutlet UITextView *inputTextView;

/** 录音按钮 */
@property (weak, nonatomic) IBOutlet UIButton *recordBtn;


// 用这个cell对象来计算cell的高度
@property (nonatomic, strong) BRChatCell *chatCellTool;

@property (nonatomic, strong) NSMutableArray *messageModelArr;
// 保存会话对象
@property (nonatomic, strong) EMConversation *conversation;

@end

@implementation BRChatViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.title = self.contactUsername;
    // 设置聊天管理器的代理（实现代理对应的方法，用来监听消息的回复）
    [[EMClient sharedClient].chatManager addDelegate:self delegateQueue:nil];
    // 监听键盘的弹出(显示)，更改toolBar底部的约束（将工具条往上移，防止被键盘挡住）
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShowToAction:) name:UIKeyboardWillShowNotification object:nil];
    
    // 监听键盘的退出(隐藏)，工具条恢复原位
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHideToAction:) name:UIKeyboardWillHideNotification object:nil];
    
    [self loadData];
}

- (void)loadData {
    // 获取一个会话
    EMConversation *conversation = [[EMClient sharedClient].chatManager getConversation:self.contactUsername type:EMConversationTypeChat createIfNotExist:YES];
    self.conversation = conversation;
    // 加载本地数据库聊天记录
    [conversation loadMessagesStartFromId:nil count:10 searchDirection:EMMessageSearchDirectionUp completion:^(NSArray *aMessages, EMError *aError) {
        if (!aError) {
            NSLog(@"获取到的消息 aMessages：%@", aMessages);
            for (EMMessage *message in aMessages) {
                // 添加消息到数据源（一个一个的添加，便于判断是否添加时间）
                [self addDataSourcesWithMessageModel:message];
            }
        }
    }];
}

#pragma mark - 添加消息到数据源
- (void)addDataSourcesWithMessageModel:(EMMessage *)msgModel {
    // 判断当前消息前是否要添加时间
    NSString *chatTimeStr = [NSDate chatTime:msgModel.timestamp];
    // 过滤时间：同一分钟内的消息，只显示一个时间（由于没有显示秒数，是为了保证显示的时间不重复）
    if (![chatTimeStr isEqualToString:_lastTimeStr]) {
        // 1.添加时间字符串到数据源
        [self.messageModelArr addObject:chatTimeStr];
        _lastTimeStr = chatTimeStr;
    }
    // 2.添加消息模型到数据源
    [self.messageModelArr addObject:msgModel];
    // 刷新UI
    [self.tableView reloadData];
    // 设置消息为已读
    id error = nil;
    [self.conversation markMessageAsReadWithId:msgModel.messageId error:&error];
    NSLog(@"设置消息为已读error = %@", error);
    
}

#pragma mark - 键盘显示时会触发的方法
- (void)keyboardWillShowToAction:(NSNotification *)sender {
    // 1.获取键盘的高度
    // 1.1 获取键盘弹出结束时的位置
    CGRect endFrame = [sender.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGFloat keyboardHeight = endFrame.size.height;
    // 2.更改工具条底部的约束
    self.toolBarBottomLayoutConstraint.constant = keyboardHeight;
    // 添加动画：保证键盘的弹出和工具条的上移 同步
    [UIView animateWithDuration:0.2 animations:^{
        // 刷新布局，重新布局子控件
        [self.view layoutIfNeeded];
    }];
}

#pragma mark - 键盘隐藏时会触发的方法
- (void)keyboardWillHideToAction:(NSNotification *)sender {
    // 工具条恢复原位
    self.toolBarBottomLayoutConstraint.constant = 0;
    [UIView animateWithDuration:0.2 animations:^{
        [self.view layoutIfNeeded];
    }];
}

#pragma mark - UITableViewDataSource, UITableViewDelegate
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.messageModelArr.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    // 判断数据源的类型
    if ([self.messageModelArr[indexPath.row] isKindOfClass:[NSString class]]) { // 显示时间的cell
        // 时间cell
        BRTimeCell *cell = [tableView dequeueReusableCellWithIdentifier:@"timeCell"];
        cell.timeLabel.text = self.messageModelArr[indexPath.row];
        return cell;
    }
    
    // 消息cell
    EMMessage *messageModel = self.messageModelArr[indexPath.row];
    static NSString *cellID = nil;
    if ([messageModel.from isEqualToString:self.contactUsername]) { //接收方（好友） 显示在左边
        cellID = @"leftCell";
    } else { // 发送方（自己）显示在右边
        cellID = @"rightCell";
    }
    BRChatCell *cell = [tableView dequeueReusableCellWithIdentifier:cellID];
    cell.messageModel = messageModel;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // 点击tableView隐藏键盘
    [self.view endEditing:YES];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    // 判断数据源的类型
    if ([self.messageModelArr[indexPath.row] isKindOfClass:[NSString class]]) { // 显示时间的cell
        return 50;
    }
    
    // 随便获取一个cell对象（目的是拿到一个模块装入数据，计算出高度）
    self.chatCellTool = [tableView dequeueReusableCellWithIdentifier:@"leftCell"];
    // 给模型赋值
    self.chatCellTool.messageModel = self.messageModelArr[indexPath.row];
    
    return [self.chatCellTool cellHeight];
}

#pragma mark - UITextViewDelegate
- (void)textViewDidChange:(UITextView *)textView {
    // 1.计算textView的高度
    CGFloat textViewH = 0;
    CGFloat minH = 34;
    CGFloat maxH = 68;
    // UITextView 继承 UIScrollView，所以可以根据contentSize的高度来确定textView的高度
    CGFloat contentHeight = textView.contentSize.height; // 内容的高度
    if (contentHeight < minH) {
        textViewH = minH;
    } else if (contentHeight > maxH) {
        textViewH = maxH;
    } else {
        textViewH = contentHeight;
    }
    
    // 2.监听send事件(判断最后一个字符是不是 "\n" 换行字符)
    if ([textView.text hasSuffix:@"\n"]) {
        NSLog(@"发送操作");
        // 清除最后的换行字符（换行字符 只占用一个长度）
        textView.text = [textView.text substringToIndex:textView.text.length - 1];
        // 发送消息
        [self sendTextMessage:textView.text];
        // 发送消息后，清空输入框
        textView.text = nil;
        // 还原toolBar的高度
        textViewH = minH;
    }
    
    // 3.调整toolBar的高度约束
    self.toolBarHeightLayoutConstraint.constant = 6 + textViewH + 6;
    // 修改约束后，一般加个动画顺畅一点
    [UIView animateWithDuration:0.3 animations:^{
        [self.view layoutIfNeeded];
    }];
    
    // 纠正光标的位置（让光标回到原位摆正）
    [textView setContentOffset:CGPointZero animated:YES];
    [textView scrollRangeToVisible:textView.selectedRange];
}

#pragma mark - 发送消息
- (void)sendMessage:(EMMessageBody *)messageBody {
    // 1.构造消息对象
    NSString *fromUsername = [[EMClient sharedClient] currentUsername];
    EMMessage *message = [[EMMessage alloc] initWithConversationID:self.contactUsername from:fromUsername to:self.contactUsername body:messageBody ext:nil];
    // 消息类型：设置为单聊消息（一对一聊天）
    message.chatType = EMChatTypeChat;
    // 2.发送消息（异步方法）
    [[EMClient sharedClient].chatManager sendMessage:message progress:nil completion:^(EMMessage *message, EMError *error) {
        if (!error) {
            NSLog(@"发送消息成功！");
        } else {
            // reason：录制的语音文件无效，太小了...
            NSLog(@"发送消息失败：%u, %@", error.code, error.errorDescription);
        }
    }];
    // 3.把消息添加到数据源，再刷新表格
    // 添加消息到数据源（一个一个的添加，便于判断是否添加时间）
    [self addDataSourcesWithMessageModel:message];
    // 4.把消息显示在顶部
    [self scrollToBottomVisible];
}

#pragma mark - 发送文本消息
- (void)sendTextMessage:(NSString *)text {
    // 构造一个文字的消息体
    EMTextMessageBody *textMsgBody = [[EMTextMessageBody alloc] initWithText:text];
    [self sendMessage:textMsgBody];
}

#pragma mark - 发送语音消息
- (void)sendVoiceMessage:(NSString *)recordPath duration:(NSInteger)duration {
    // 构造一个语音的消息体 （displayName 会话中列表中，显示的名字）
    EMVoiceMessageBody *voiceBody = [[EMVoiceMessageBody alloc]initWithLocalPath:recordPath displayName:@"[语音]"];
    voiceBody.duration = (int)duration;
    [self sendMessage:voiceBody];
}

#pragma mark - 发送图片消息
- (void)sendImageMessage:(UIImage *)image {
    // 构造图片消息体
    NSData *originalImageData = UIImagePNGRepresentation(image);
    EMImageMessageBody *imageMsgBody = [[EMImageMessageBody alloc]initWithData:originalImageData thumbnailData:nil];
    [self sendMessage:imageMsgBody];
}

- (void)scrollToBottomVisible {
    if (self.messageModelArr.count == 0) {
        return;
    }
    // 获取最后一行
    NSIndexPath *lastIndex = [NSIndexPath indexPathForRow:self.messageModelArr.count - 1 inSection:0];
    // 滚动到底部可见
    [self.tableView scrollToRowAtIndexPath:lastIndex atScrollPosition:UITableViewScrollPositionBottom animated:YES];
}

#pragma mark - 监听好友回复消息（收到消息的回调）
- (void)messagesDidReceive:(NSArray *)aMessages {
    for (EMMessage *message in aMessages) {
        // from 一定等于当前聊天用户（防止与用户A聊天时，用户B也发来消息，产生干扰。收到用户B的回复消息也会执行这个回调）
        if ([message.from isEqualToString:self.contactUsername]) {
            // 把接收的消息添加到数据源
            [self addDataSourcesWithMessageModel:message];
            // 显示数据到底部
            [self scrollToBottomVisible];
        }
    }
}

#pragma mark - 声音按钮事件
- (IBAction)clickVoiceBtn:(UIButton *)sender {
    sender.selected = !sender.isSelected;
    // 显示录音按钮
    self.recordBtn.hidden = !self.recordBtn.hidden;
    self.inputTextView.hidden = !self.inputTextView.hidden;
    
    if (self.recordBtn.hidden == NO) {
        // 让保证 bottomToolBar 的高度回到默认的高度
        self.toolBarHeightLayoutConstraint.constant = 46;
        // 隐藏键盘
        [self.view endEditing:YES];
    } else {
        // 显示键盘
        [self.inputTextView becomeFirstResponder];
        // 恢复 bottomToolBar 的高度（自适应文字的高度）
        [self textViewDidChange:self.inputTextView];
    }
}

#pragma mark - 按钮点下去开始录音
- (IBAction)recordBtnWhenTouchDown:(id)sender {
    NSLog(@"开始录音");
    [[EMCDDeviceManager sharedInstance] asyncStartRecordingWithFileName:[NSDate currentTimestamp] completion:^(NSError *error) {
        if (!error) {
            NSLog(@"开始录音成功！");
        } else {
            NSLog(@"录音失败：%@", error);
        }
    }];
}

#pragma mark - 手指从按钮范围外松开取消录音
- (IBAction)recordBtnWhenTouchUpOutside:(id)sender {
    NSLog(@"取消录音");
    [[EMCDDeviceManager sharedInstance] cancelCurrentRecording];
}

#pragma mark - 手指从按钮范围内松开结束录音（发送语音到服务器）
- (IBAction)recordBtnWhenTouchUpInside:(id)sender {
    NSLog(@"结束录音");
    [[EMCDDeviceManager sharedInstance] asyncStopRecordingWithCompletion:^(NSString *recordPath, NSInteger aDuration, NSError *error) {
        if (!error) {
            NSLog(@"录音成功！");
            NSLog(@"录音路径：%@， 录音时长：%ld", recordPath, aDuration);
            // 发送语音到服务器
            [self sendVoiceMessage:recordPath duration:aDuration];
        } else {
            NSLog(@"录音失败：%@", error);
        }
    }];
}

#pragma mark - 更多按钮事件
- (IBAction)clickMoreBtn:(UIButton *)sender {
    NSLog(@"更多");
    
    // 显示图片选择的控制器
    UIImagePickerController *imagePicker = [[UIImagePickerController alloc]init];
    // 设置源
    imagePicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    imagePicker.delegate = self;
    [self presentViewController:imagePicker animated:YES completion:nil];
    
}

#pragma mark - 用户选中图片之后的回调
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info {
    // 获取用户选中的图片
    UIImage *image = info[UIImagePickerControllerOriginalImage];
    // 发送图片
    [self sendImageMessage:image];
    // 隐藏当前图片选择控制器
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - 开始拖拽
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    // 通知语音的播放
    [BRVoicePlayTool stopPlaying];
}

- (NSMutableArray *)messageModelArr {
    if (!_messageModelArr) {
        _messageModelArr = [[NSMutableArray alloc]init];
    }
    return _messageModelArr;
}

- (void)dealloc {
    // 移除通知
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[EMClient sharedClient].chatManager removeDelegate:self];
}

@end
